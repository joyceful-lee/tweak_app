import { ApiError, uuid, text, strings, status, versionBody } from './validation.mjs';

export async function owners(db, user) {
  const { rows } = await db.query('select legacy_user_id from tweak_migrations.owners where neon_user_id = $1', [uuid(user.id)]);
  const ids = [...new Set([user.id, ...rows.map(row => row.legacy_user_id)])];
  return { ids, primary: rows[0]?.legacy_user_id || user.id };
}
export async function claimOwner(db, user) {
  if (user.emailVerified !== true || !user.email) throw new ApiError(403, 'Verify your email before restoring recipes.');
  const { rows } = await db.query(`select * from tweak_migrations.owners
    where lower(source_email) = lower($1) and source_email_verified for update`, [user.email]);
  if (rows.length !== 1) throw new ApiError(409, 'No unique verified previous account was found. Contact the app owner to link it manually.');
  if (rows[0].neon_user_id && rows[0].neon_user_id !== user.id) throw new ApiError(409, 'This previous account has already been restored.');
  await db.query('update tweak_migrations.owners set neon_user_id=$1, linked_at=now() where legacy_user_id=$2', [uuid(user.id), rows[0].legacy_user_id]);
  return { restored: true };
}
async function dishForUpdate(db, id, owner) {
  const { rows } = await db.query('select * from public.dishes where id=$1 and user_id=any($2::uuid[]) for update', [uuid(id), owner.ids]);
  if (!rows.length) throw new ApiError(404, 'Recipe not found.');
  return rows[0];
}
async function validatePhotos(db, paths, owner) {
  if (!paths.length) return;
  const { rows } = await db.query('select id from public.recipe_photos where id=any($1::uuid[]) and user_id=any($2::uuid[])', [paths, owner.ids]);
  if (rows.length !== new Set(paths).size) throw new ApiError(400, 'One or more photos are unavailable.');
}
export async function recipeOperation(db, user, method, path, body = {}) {
  const owner = await owners(db, user);
  if (path === 'account' && method === 'GET') {
    const { rows } = await db.query(`select count(*)::integer as count from tweak_migrations.owners
      where lower(source_email)=lower($1) and neon_user_id is null`, [user.email || '']);
    return { email: user.email, emailVerified: user.emailVerified === true,
      restoreAvailable: rows[0].count > 0, restored: owner.ids.length > 1 };
  }
  if (path === 'account/claim' && method === 'POST') return claimOwner(db, user);
  if (path === 'dishes' && method === 'GET') {
    return (await db.query(`select d.id,d.name,d.description,d.status,d.best_version,d.created_at,
      case when v.id is null then null else to_jsonb(v)-'legacy_payload' end as best
      from public.dishes d left join public.dish_versions v on v.id=d.best_version
      where d.user_id=any($1::uuid[]) order by d.created_at desc`, [owner.ids])).rows;
  }
  if (path === 'dishes/export' && method === 'GET') {
    return (await db.query(`select d.id,d.name,d.description,d.status,d.best_version,d.created_at,
      coalesce((select jsonb_agg(to_jsonb(v)-'legacy_payload' order by v.version_number)
      from public.dish_versions v where v.dish_id=d.id),'[]') as dish_versions
      from public.dishes d where d.user_id=any($1::uuid[]) order by d.created_at desc`, [owner.ids])).rows;
  }
  if (path === 'dishes' && method === 'POST') {
    const name=text(body.name,300), description=text(body.description ?? ''), state=status(body.status);
    if (!name) throw new ApiError(400, 'A recipe name is required.');
    const version=versionBody(body); await validatePhotos(db,version.photo_paths,owner);
    const { rows: [dish] } = await db.query(`insert into public.dishes(user_id,name,description,status)
      values($1,$2,$3,$4) returning id`, [owner.primary,name,description,state]);
    await db.query(`insert into public.dish_versions(dish_id,version_number,ingredients,directions,notes,tags,status,photo_paths)
      values($1,1,$2,$3,$4,$5,$6,$7)`, [dish.id,version.ingredients,version.directions,version.notes,version.tags,state,version.photo_paths]);
    return dish;
  }
  const dishMatch=path.match(/^dishes\/([^/]+)(?:\/(versions|best))?$/);
  if (dishMatch) {
    const dish=await dishForUpdate(db,dishMatch[1],owner), section=dishMatch[2];
    if (!section && method === 'GET') { const {legacy_payload,...publicDish}=dish; return publicDish; }
    if (!section && method === 'PATCH') {
      await db.query('update public.dishes set status=$1 where id=$2',[status(body.status),dish.id]);return {saved:true};
    }
    if (!section && method === 'DELETE') {
      await db.query('update public.dishes set best_version=null where id=$1',[dish.id]);
      await db.query('delete from public.dishes where id=$1',[dish.id]);return {deleted:true};
    }
    if (section === 'versions' && method === 'GET') {
      return (await db.query("select to_jsonb(v)-'legacy_payload' as version from public.dish_versions v where dish_id=$1 order by version_number",[dish.id])).rows.map(row=>row.version);
    }
    if (section === 'versions' && method === 'POST') {
      const base=await db.query('select 1 from public.dish_versions where id=$1 and dish_id=$2',[uuid(body.base_version_id),dish.id]);
      if (!base.rowCount) throw new ApiError(404,'Base version not found.');
      const version=versionBody(body);await validatePhotos(db,version.photo_paths,owner);
      const { rows:[created] }=await db.query(`insert into public.dish_versions
        (dish_id,version_number,ingredients,directions,notes,tags,status,photo_paths)
        select $1,coalesce(max(version_number),0)+1,$2,$3,$4,$5,$6,$7
        from public.dish_versions where dish_id=$1 returning *`,
        [dish.id,version.ingredients,version.directions,version.notes,version.tags,dish.status,version.photo_paths]);
      delete created.legacy_payload;return created;
    }
    if (section === 'best' && method === 'PATCH') {
      const version=await db.query('select 1 from public.dish_versions where id=$1 and dish_id=$2',[uuid(body.version_id),dish.id]);
      if (!version.rowCount) throw new ApiError(404,'Version not found.');
      await db.query('update public.dishes set best_version=$1 where id=$2',[body.version_id,dish.id]);return {saved:true};
    }
  }
  const versionMatch=path.match(/^versions\/([^/]+)$/);
  if (versionMatch) {
    const id=uuid(versionMatch[1]);
    const { rows }=await db.query(`select v.dish_id from public.dish_versions v join public.dishes d on d.id=v.dish_id
      where v.id=$1 and d.user_id=any($2::uuid[])`,[id,owner.ids]);
    if (!rows.length) throw new ApiError(404,'Version not found.');
    await dishForUpdate(db,rows[0].dish_id,owner);
    if (method === 'PATCH') {
      const version=versionBody(body);await validatePhotos(db,version.photo_paths,owner);
      await db.query('update public.dish_versions set ingredients=$1,directions=$2,notes=$3,tags=$4,photo_paths=$5 where id=$6',
        [version.ingredients,version.directions,version.notes,version.tags,version.photo_paths,id]);return {saved:true};
    }
    if (method === 'DELETE') {
      await db.query('update public.dishes set best_version=null where best_version=$1',[id]);
      await db.query('delete from public.dish_versions where id=$1',[id]);return {deleted:true};
    }
  }
  if (path === 'notes' && method === 'GET') {
    return (await db.query('select id,user_id,title,content,tags,created_at from public.notes where user_id=any($1::uuid[]) order by created_at desc',[owner.ids])).rows;
  }
  if (path === 'notes' && method === 'POST') {
    return (await db.query('insert into public.notes(user_id,title,content,tags) values($1,$2,$3,$4) returning id',
      [owner.primary,text(body.title,500),text(body.content,100000),strings(body.tags ?? [])])).rows[0];
  }
  const noteMatch=path.match(/^notes\/([^/]+)$/);
  if (noteMatch && ['PATCH','DELETE'].includes(method)) {
    const id=uuid(noteMatch[1]);
    const result=method === 'DELETE'
      ? await db.query('delete from public.notes where id=$1 and user_id=any($2::uuid[])',[id,owner.ids])
      : await db.query('update public.notes set title=$1,content=$2,tags=$3 where id=$4 and user_id=any($5::uuid[])',
        [text(body.title,500),text(body.content,100000),strings(body.tags ?? []),id,owner.ids]);
    if (!result.rowCount) throw new ApiError(404,'Note not found.');return {saved:true};
  }
  throw new ApiError(404,'Unknown operation.');
}
