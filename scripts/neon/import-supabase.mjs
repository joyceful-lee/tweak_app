import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { connectDatabase, reportError } from './db.mjs';
import { prepareSnapshot, requirePhotosTransferred, verifyImportedRows } from './snapshot.mjs';

let target;
try {
  const args = process.argv.slice(2);
  const filename = args.find(arg => !arg.startsWith('--'));
  if (!filename || args.some(arg => arg.startsWith('--') && arg !== '--apply') ||
      args.filter(arg => !arg.startsWith('--')).length !== 1) {
    throw new Error('Usage: npm run db:import:supabase -- <snapshot.json> [--apply]. Default is dry run.');
  }
  const bytes = await readFile(filename);
  const snapshot = prepareSnapshot(JSON.parse(bytes.toString('utf8')));
  const digest = createHash('sha256').update(bytes).digest('hex');
  target = await connectDatabase();
  await target.query('begin');
  await target.query("select pg_advisory_xact_lock(hashtext('tweak:data-import'))");
  // Prevent a concurrent app write between the empty-target check and inserts.
  await target.query('lock table public.dishes, public.dish_versions, public.notes in exclusive mode');
  const { rows: imported } = await target.query(
    'select snapshot_sha256 from tweak_migrations.imports where snapshot_sha256 = $1', [digest]);
  if (imported.length) {
    await target.query('rollback');
    console.log('This exact snapshot was already imported. No changes made.');
  } else {
    const { rows: [counts] } = await target.query(`select
      (select count(*)::integer from public.dishes) as dishes,
      (select count(*)::integer from public.dish_versions) as dish_versions,
      (select count(*)::integer from public.notes) as notes,
      (select count(*)::integer from tweak_migrations.owners) as owners`);
    if (Object.values(counts).some(count => count !== 0)) {
      throw new Error('Target already contains recipe or ownership data. Refusing to merge or overwrite it.');
    }
    if (!args.includes('--apply')) {
      await target.query('rollback');
      console.log(JSON.stringify({ mode: 'dry-run', target_empty: true, counts: snapshot.counts,
        photo_transfer_required: snapshot.photoPaths.length > 0, changes_written: false }, null, 2));
    } else {
      requirePhotosTransferred(snapshot);
      for (const owner of snapshot.owners) {
        await target.query(`insert into tweak_migrations.owners
          (legacy_user_id, source_email, source_email_verified) values ($1, $2, $3)`,
        [owner.id, owner.email, owner.email_verified]);
      }
      const insert = async (table, columns, rows) => {
        const placeholders = columns.map((_, index) => `$${index + 1}`).join(',');
        for (const row of rows) {
          await target.query(`insert into public.${table} (${columns.join(',')}) values (${placeholders})`,
            columns.map(column => column === 'legacy_payload' ? JSON.stringify(row[column]) : row[column]));
        }
      };
      await insert('dishes', ['id', 'user_id', 'name', 'description', 'status', 'best_version', 'created_at', 'legacy_payload'], snapshot.dishes);
      await insert('dish_versions', ['id', 'dish_id', 'version_number', 'ingredients', 'directions', 'notes', 'tags', 'status', 'photo_paths', 'created_at', 'legacy_payload'], snapshot.versions);
      await insert('notes', ['id', 'user_id', 'title', 'content', 'tags', 'created_at', 'legacy_payload'], snapshot.notes);
      const { rows: [actual] } = await target.query(`select
        (select count(*)::integer from public.dishes) as dishes,
        (select count(*)::integer from public.dish_versions) as dish_versions,
        (select count(*)::integer from public.notes) as notes,
        (select count(*)::integer from tweak_migrations.owners) as owners`);
      for (const name of ['dishes', 'dish_versions', 'notes', 'owners']) {
        if (actual[name] !== snapshot.counts[name]) throw new Error('Post-import count verification failed. Rolling back.');
      }
      for (const [table, expected] of [
        ['dishes', snapshot.dishes], ['dish_versions', snapshot.versions], ['notes', snapshot.notes],
      ]) {
        if (!expected.length) continue;
        const columns = Object.keys(expected[0]);
        const { rows } = await target.query(`select ${columns.join(',')} from public.${table} order by id`);
        verifyImportedRows(expected, rows);
      }
      await target.query('insert into tweak_migrations.imports (snapshot_sha256, counts) values ($1, $2)',
        [digest, JSON.stringify(snapshot.counts)]);
      await target.query('commit');
      console.log(JSON.stringify({ mode: 'applied', verified_counts: actual,
        source_modified: false, application_cutover: false, account_links_pending: true }, null, 2));
    }
  }
} catch (error) {
  if (target) await target.query('rollback').catch(() => {});
  reportError(error);
} finally { await target?.end(); }
