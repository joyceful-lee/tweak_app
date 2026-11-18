import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { checkOrigin, requestOrigin, oauthDestination, seal, unseal, digest, sameDigest, nativeRequest, proveRestoration } from '../../server/auth.mjs';
import { uuid, versionBody, imageType } from '../../server/validation.mjs';
import { handle } from '../../server/app.mjs';

test('rejects cross-origin mutation and missing web origin',()=>{
  assert.throws(()=>checkOrigin(new Request('https://tweak-recipes.vercel.app/api/dishes',{
    method:'POST',headers:{origin:'https://attacker.invalid'}})),/origin/);
  assert.throws(()=>checkOrigin(new Request('https://tweak-recipes.vercel.app/api/dishes',{
    method:'POST',headers:{cookie:'anything=present'}})),/origin/);
});
test('custom domain keeps OAuth on its own host and rejects lookalike origins',()=>{
  for (const origin of ['https://tweak.joyceful-lee.com','https://tweak-recipes.vercel.app']) {
    const request = new Request(`${origin}/api/auth/google`,{headers:{origin}});
    assert.doesNotThrow(()=>checkOrigin(request));
    assert.equal(requestOrigin(request),origin);
    assert.equal(nativeRequest(new Request(`${origin}/api/session`)).headers.get('origin'),origin);
  }
  const fake='https://tweak.joyceful-lee.com.attacker.invalid';
  assert.throws(()=>checkOrigin(new Request(`${fake}/api/dishes`,{method:'POST',headers:{origin:fake}})),/origin/);
  assert.equal(requestOrigin(new Request(`${fake}/api/auth/google`)),'https://tweak-recipes.vercel.app');
});
test('OAuth accepts the configured Neon initiation route and rejects unrelated redirects',()=>{
  const oldBase=process.env.NEON_AUTH_BASE_URL, oldSecret=process.env.NEON_AUTH_COOKIE_SECRET;
  process.env.NEON_AUTH_BASE_URL='https://auth.example.invalid/neondb/auth';
  process.env.NEON_AUTH_COOKIE_SECRET='synthetic-config-only';
  try {
    const start='https://auth.example.invalid/neondb/auth/sign-in/social/init?state=synthetic';
    assert.equal(oauthDestination(start),start);
    assert.equal(oauthDestination('https://accounts.google.com/o/oauth2/auth'),'https://accounts.google.com/o/oauth2/auth');
    for(const bad of ['https://attacker.invalid/neondb/auth/sign-in/social/init',
      'https://auth.example.invalid/other','http://accounts.google.com/',
      'https://auth.example.invalid.attacker.invalid/neondb/auth/sign-in/social/init',
      'https://user:secret@auth.example.invalid/neondb/auth/sign-in/social/init']) {
      assert.throws(()=>oauthDestination(bad),/Unexpected sign-in/);
    }
  } finally {
    if(oldBase)process.env.NEON_AUTH_BASE_URL=oldBase;else delete process.env.NEON_AUTH_BASE_URL;
    if(oldSecret)process.env.NEON_AUTH_COOKIE_SECRET=oldSecret;else delete process.env.NEON_AUTH_COOKIE_SECRET;
  }
});
test('mobile session handoff encryption detects tampering',()=>{
  const old=process.env.NEON_AUTH_COOKIE_SECRET;
  process.env.NEON_AUTH_COOKIE_SECRET=randomBytes(48).toString('base64url');
  process.env.NEON_AUTH_BASE_URL='https://auth.example.invalid/auth';
  const sealed=seal('provider-issued-cookie');
  assert.equal(unseal(sealed),'provider-issued-cookie');
  const changed=Buffer.from(sealed,'base64url');changed[changed.length-1]^=1;
  assert.throws(()=>unseal(changed.toString('base64url')));
  if(old)process.env.NEON_AUTH_COOKIE_SECRET=old;else delete process.env.NEON_AUTH_COOKIE_SECRET;
});
test('PKCE handoff rejects a different verifier',()=>{
  const verifier=randomBytes(32).toString('base64url');
  assert.equal(sameDigest(digest(verifier),digest(verifier)),true);
  assert.equal(sameDigest(digest(verifier),digest('wrong')),false);
  assert.equal(sameDigest(digest(verifier),undefined),false);
});
test('restoring imported accounts requires fresh email proof, not just a session',async()=>{
  await assert.rejects(()=>proveRestoration(new Request('https://tweak-recipes.vercel.app/api/account/claim'),[],
    {id:'user',emailVerified:true},undefined),/fresh code/);
});
test('native header cannot inject arbitrary cookies or newlines',()=>{
  const token=Buffer.from('unrelated-cookie=anything').toString('base64url');
  assert.throws(()=>nativeRequest(new Request('https://tweak-recipes.vercel.app/api/session',{
    headers:{authorization:`Bearer ${token}`}})),/sign in/);
  const valid=Buffer.from('__Secure-neon-auth.session_token=synthetic-session').toString('base64url');
  const adapted=nativeRequest(new Request('https://tweak-recipes.vercel.app/api/session',{headers:{authorization:`Bearer ${valid}`}}));
  assert.equal(adapted.headers.has('authorization'),false);
  assert.equal(adapted.headers.get('cookie'),'__Secure-neon-auth.session_token=synthetic-session');
});
test('validates IDs, recipe contents, photo count, and image bytes',()=>{
  assert.throws(()=>uuid("' or true --"),/record ID/);
  assert.throws(()=>versionBody({ingredients:[],directions:['step']}),/cannot be empty/);
  assert.throws(()=>versionBody({ingredients:['salt'],directions:['mix'],photo_paths:Array(11).fill('x')}),/list/);
  assert.throws(()=>imageType(Buffer.from('<svg onload=alert(1)>')),/JPEG/);
  assert.throws(()=>imageType(Buffer.alloc(4194305)),/4 MB/);
});
test('health reveals no private configuration and unknown origins are rejected',async()=>{
  const result=await handle(new Request('https://tweak-recipes.vercel.app/api/health'));
  assert.equal(result.status,200);
  assert.deepEqual(await result.json(),{ok:true,backend:'neon',photos:'private',version:2});
  const rejected=await handle(new Request('https://tweak-recipes.vercel.app/api/health',{headers:{origin:'https://attacker.invalid'}}));
  assert.equal(rejected.status,403);
});
