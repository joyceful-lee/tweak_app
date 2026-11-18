import { randomBytes, randomUUID } from 'node:crypto';
import { put, get, del } from '@vercel/blob';
import { database, transaction } from './db.mjs';
import { ApiError, uuid, imageType } from './validation.mjs';
import { recipeOperation, owners } from './recipes.mjs';
import { requestOrigin, checkOrigin, nativeRequest, identity, mergedSession, proxyAuth,
  oauthProxy, oauthComplete, oauthDestination, digest, sameDigest, seal, unseal, proveRestoration } from './auth.mjs';

const json=(data,status=200,cookies=[])=>new Response(JSON.stringify(data),{status,headers:[
  ['content-type','application/json'],['cache-control','no-store'],['x-content-type-options','nosniff'],
  ...cookies.map(value=>['set-cookie',value]),
]});
const redirects=(url,cookies=[])=>new Response(null,{status:302,headers:[['location',url],['cache-control','no-store'],...cookies.map(c=>['set-cookie',c])]});
export async function handle(original) {
  const cookies=[];
  try {
    checkOrigin(original);
    const request=nativeRequest(original), url=new URL(request.url);
    const path=(url.searchParams.get('route') || url.pathname.replace(/^\/api\//,'')).replace(/^\/+|\/+$/g,'');
    if (path === 'health' && request.method === 'GET') return json({ok:true,backend:'neon',photos:'private',version:2});
    if (path === 'auth/mobile/start' && request.method === 'POST') {
      const {challenge}=await request.json();
      if (typeof challenge !== 'string' || !/^[0-9a-f]{64}$/.test(challenge)) throw new ApiError(400,'Invalid login challenge.');
      const {rows:[row]}=await database().query(`with cleanup as (delete from tweak_migrations.mobile_login where expires_at<now())
        insert into tweak_migrations.mobile_login(challenge) values($1) returning id`,[challenge]);
      return json({url:`${requestOrigin(request)}/api/auth/google?mobile=${row.id}`});
    }
    if (path === 'auth/mobile/exchange' && request.method === 'POST') {
      const body=await request.json();
      if (typeof body.verifier !== 'string' || body.verifier.length < 43 || body.verifier.length > 128 || typeof body.code !== 'string') throw new ApiError(400,'Invalid login exchange.');
      return await transaction(async db=>{
        const {rows:[row]}=await db.query('select * from tweak_migrations.mobile_login where id=$1 and expires_at>now() for update',[uuid(body.request)]);
        if (!row || !sameDigest(row.challenge,digest(body.verifier)) || !sameDigest(row.code_hash,digest(body.code))) throw new ApiError(401,'Login link expired or invalid.');
        const session=unseal(row.encrypted_session);
        await db.query('delete from tweak_migrations.mobile_login where id=$1',[row.id]);
        return json({mobileSession:Buffer.from(session).toString('base64url')});
      });
    }
    if (path === 'auth/google' && request.method === 'GET') {
      const mobile=url.searchParams.get('mobile');
      if (mobile) {
        const exists=await database().query('select 1 from tweak_migrations.mobile_login where id=$1 and expires_at>now()',[uuid(mobile)]);
        if (!exists.rowCount) throw new ApiError(400,'Login request expired.');
      }
      const callback=`${requestOrigin(request)}/api/auth/complete${mobile?`?mobile=${mobile}`:''}`;
      const headers=new Headers(request.headers);headers.set('content-type','application/json');
      const response=await oauthProxy(new Request(`${requestOrigin(request)}/api/auth/sign-in/social`,{
        method:'POST',headers,body:JSON.stringify({provider:'google',callbackURL:callback})}));
      const data=await response.json();
      if (data.code === 'INVALID_ORIGIN') throw new ApiError(503,'Add this website to Neon Auth trusted domains to enable Google sign-in.');
      if (!response.ok || !data.url) return json({message:data.message || 'Google sign-in could not start.'},response.status || 502);
      return redirects(oauthDestination(data.url),response.headers.getSetCookie());
    }
    if (path === 'auth/complete' && request.method === 'GET') {
      const result=await oauthComplete(request);
      cookies.push(...(result.cookies || []));
      if (result.action !== 'allow') return redirects(result.redirectUrl.toString(),cookies);
      const mobile=url.searchParams.get('mobile');
      if (mobile) {
        await identity(request,cookies);
        const code=randomBytes(32).toString('base64url');
        const session=mergedSession(request.headers.get('cookie'),cookies);
        const row=await database().query(`update tweak_migrations.mobile_login set code_hash=$1,encrypted_session=$2,
          expires_at=now()+interval '2 minutes' where id=$3 and expires_at>now() and code_hash is null`,
          [digest(code),seal(session),uuid(mobile)]);
        if (!row.rowCount) throw new ApiError(400,'Login request expired.');
        return redirects(`com.tweakapp://login?request=${mobile}&code=${code}`,cookies);
      }
      return redirects(`${requestOrigin(request)}/`,cookies);
    }
    if (path.startsWith('auth/')) {
      const response=await proxyAuth(request,path.slice(5));
      const data=await response.json().catch(()=>({}));
      if (data.code === 'INVALID_ORIGIN') return json({message:'Sign-in setup needs this website added to Neon Auth trusted domains.'},503);
      const outgoing=response.headers.getSetCookie();
      const session=mergedSession(request.headers.get('cookie'),outgoing);
      // Web sessions remain in HttpOnly cookies. Native clients use encrypted
      // device storage for the same provider-issued session credential.
      if (!original.headers.has('origin') && original.headers.get('x-tweak-client') === 'native' && session) {
        data.mobileSession=Buffer.from(session).toString('base64url');
      }
      return json(data,response.status,outgoing);
    }
    const user=await identity(request,cookies);
    if (path === 'session' && request.method === 'GET') return json({user:{id:user.id,email:user.email,emailVerified:user.emailVerified}},200,cookies);
    if (path === 'account/claim' && request.method === 'POST') {
      const {otp}=await request.json();
      const verified=await proveRestoration(request,cookies,user,otp);
      const result=await transaction(db=>recipeOperation(db,verified,'POST','account/claim'));
      if (!original.headers.has('origin') && original.headers.get('x-tweak-client') === 'native') {
        result.mobileSession=Buffer.from(mergedSession(request.headers.get('cookie'),cookies)).toString('base64url');
      }
      return json(result,200,cookies);
    }
    if (path === 'photos' && request.method === 'POST') {
      const bytes=Buffer.from(await request.arrayBuffer()),contentType=imageType(bytes);
      if (user.emailVerified !== true) throw new ApiError(403,'Verify your email before uploading photos.');
      const owner=await owners(database(),user), id=randomUUID();
      const extension=contentType.split('/')[1].replace('jpeg','jpg');
      const blob=await put(`${owner.primary}/${id}.${extension}`,bytes,{access:'private',contentType,addRandomSuffix:false});
      try { await database().query('insert into public.recipe_photos(id,user_id,blob_path,content_type,byte_size) values($1,$2,$3,$4,$5)',
        [id,owner.primary,blob.url,contentType,bytes.length]); }
      catch(error){await del(blob.url).catch(()=>{});throw error;}
      return json({path:id},201,cookies);
    }
    const photo=path.match(/^photos\/([^/]+)$/);
    if (photo) {
      const owner=await owners(database(),user);
      const {rows:[row]}=await database().query('select * from public.recipe_photos where id=$1 and user_id=any($2::uuid[])',[uuid(photo[1]),owner.ids]);
      if (!row) throw new ApiError(404,'Photo not found.');
      if (request.method === 'GET') {
        const file=await get(row.blob_path,{access:'private'});
        if (!file || file.statusCode !== 200) throw new ApiError(404,'Photo not found.');
        return new Response(file.stream,{headers:[['content-type',row.content_type],['cache-control','private, no-store'],
          ['x-content-type-options','nosniff'],...cookies.map(c=>['set-cookie',c])]});
      }
      if (request.method === 'DELETE') {
        const {rowCount}=await database().query('select 1 from public.dish_versions where $1=any(photo_paths) limit 1',[row.id]);
        if (rowCount) throw new ApiError(409,'This photo is used by a saved recipe version.');
        await del(row.blob_path);
        await database().query('delete from public.recipe_photos where id=$1',[row.id]);
        return json({deleted:true},200,cookies);
      }
      throw new ApiError(405,'Method not allowed.');
    }
    const body=['POST','PATCH'].includes(request.method)?await request.json():{};
    const result=await transaction(db=>recipeOperation(db,user,request.method,path,body));
    return json(result,200,cookies);
  } catch(error) {
    if (error instanceof SyntaxError) return json({message:'Invalid JSON request.'},400,cookies);
    if (!(error instanceof ApiError)) console.error('Tweak API request failed:',error.code || error.name);
    return json({message:error instanceof ApiError?error.message:'The server could not complete this request. Please try again.'},error.status || 500,cookies);
  }
}
