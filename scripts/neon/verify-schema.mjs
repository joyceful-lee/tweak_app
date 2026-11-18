import { randomUUID } from 'node:crypto';
import { connectDatabase, reportError } from './db.mjs';
import { verifyImportedRows } from './snapshot.mjs';

let db;
const counts = async () => (await db.query(`select
  (select count(*)::integer from public.dishes) as dishes,
  (select count(*)::integer from public.dish_versions) as versions,
  (select count(*)::integer from public.notes) as notes`)).rows[0];
try {
  db = await connectDatabase();
  await db.query('begin');
  await db.query("select pg_advisory_xact_lock(hashtext('tweak:data-import'))");
  const baseline = await counts();
  const { rows: security } = await db.query(`select c.relname, c.relrowsecurity,
    (select count(*)::integer from pg_policy p where p.polrelid = c.oid) as policy_count,
    (select count(*)::integer from aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
      where a.grantee = 0) as public_grants
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('dishes', 'dish_versions', 'notes')`);
  if (security.length !== 3 || security.some(row => !row.relrowsecurity || row.policy_count || row.public_grants)) {
    throw new Error('Staging table access is not closed as expected.');
  }
  const owner = randomUUID(), dish = randomUUID(), otherDish = randomUUID(), version = randomUUID();
  await db.query('insert into public.dishes (id, user_id, name) values ($1,$2,$3), ($4,$2,$3)',
    [dish, owner, 'Temporary migration verification', otherDish]);
  await db.query(`insert into public.dish_versions (id, dish_id, version_number, ingredients, directions)
    values ($1,$2,3,$3,$4)`, [version, dish, ['1 tsp salt', '½ cup flour'], ['Mix\nthen rest']]);
  await db.query('update public.dishes set best_version = $1 where id = $2', [version, dish]);
  await db.query('set constraints all immediate');
  const { rows } = await db.query('select id, dish_id, version_number, ingredients, directions from public.dish_versions where id = $1', [version]);
  verifyImportedRows([{ id: version, dish_id: dish, version_number: 3,
    ingredients: ['1 tsp salt', '½ cup flour'], directions: ['Mix\nthen rest'] }], rows);

  const rejects = async (action, code) => {
    await db.query('savepoint expected_failure');
    let caught;
    try { await action(); } catch (error) { caught = error; }
    await db.query('rollback to savepoint expected_failure');
    await db.query('release savepoint expected_failure');
    if (caught?.code !== code) throw new Error(`Database constraint verification failed; expected ${code}.`);
  };
  await rejects(() => db.query('insert into public.dish_versions (dish_id, version_number) values ($1,3)', [dish]), '23505');
  await rejects(() => db.query('update public.dishes set best_version = $1 where id = $2', [version, otherDish]), '23503');
  await db.query('update public.dishes set best_version = null where id = $1', [dish]);
  await db.query('delete from public.dishes where id = $1', [dish]);
  if ((await db.query('select 1 from public.dish_versions where id = $1', [version])).rowCount) {
    throw new Error('Recipe version cascade verification failed.');
  }
  await db.query('rollback');
  const after = await counts();
  if (JSON.stringify(baseline) !== JSON.stringify(after)) throw new Error('Verification rollback did not preserve table counts.');
  console.log(JSON.stringify({ staging_access_closed: true, text_arrays_roundtrip: true,
    version_uniqueness: true, best_version_ownership: true, cascade_delete: true,
    verification_changes_rolled_back: true }, null, 2));
} catch (error) {
  if (db) await db.query('rollback').catch(() => {});
  reportError(error);
} finally { await db?.end(); }
