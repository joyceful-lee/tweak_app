import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { connectDatabase, reportError } from './db.mjs';
import { prepareSnapshot, verifyImportedRows } from './snapshot.mjs';

let db;
try {
  if (process.argv.length !== 3) throw new Error('Usage: node --env-file=.env.local scripts/neon/audit-snapshot.mjs <snapshot.json>');
  const bytes = await readFile(process.argv[2]);
  const snapshot = prepareSnapshot(JSON.parse(bytes.toString('utf8')));
  const digest = createHash('sha256').update(bytes).digest('hex');
  db = await connectDatabase();
  await db.query('begin isolation level repeatable read read only');
  for (const [table, expected] of [
    ['dishes', snapshot.dishes], ['dish_versions', snapshot.versions], ['notes', snapshot.notes],
  ]) {
    if (!expected.length) {
      if ((await db.query(`select 1 from public.${table} limit 1`)).rowCount) {
        throw new Error('Target has records not present in the snapshot.');
      }
      continue;
    }
    const columns = Object.keys(expected[0]);
    const { rows } = await db.query(`select ${columns.join(',')} from public.${table} order by id`);
    verifyImportedRows(expected, rows);
  }
  const { rows: owners } = await db.query(`select legacy_user_id as id, source_email as email,
    source_email_verified as email_verified from tweak_migrations.owners order by legacy_user_id`);
  verifyImportedRows(snapshot.owners, owners);
  const { rowCount } = await db.query('select 1 from tweak_migrations.imports where snapshot_sha256 = $1', [digest]);
  if (rowCount !== 1) throw new Error('The import ledger does not match this snapshot.');
  const { rows: [pending] } = await db.query('select count(*)::integer as count from tweak_migrations.owners where neon_user_id is null');
  await db.query('commit');
  console.log(JSON.stringify({ all_imported_fields_verified: true, counts: snapshot.counts,
    owner_links_pending: pending.count }, null, 2));
} catch (error) {
  if (db) await db.query('rollback').catch(() => {});
  reportError(error);
} finally { await db?.end(); }
