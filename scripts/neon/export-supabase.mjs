import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { connectDatabase, reportError } from './db.mjs';
import { prepareSnapshot } from './snapshot.mjs';

let source;
try {
  source = await connectDatabase({ source: true });
  await source.query('begin isolation level repeatable read read only');
  const tables = {};
  for (const table of ['dishes', 'dish_versions', 'notes']) {
    tables[table] = (await source.query(`select * from public.${table} order by id`)).rows;
  }
  // Export only the identity fields needed to preserve recipe ownership.
  // Password hashes, tokens, auth sessions, and unrelated users are excluded.
  const owners = (await source.query(`select id, email,
      email_confirmed_at is not null as email_verified from auth.users
    where id in (select user_id from public.dishes union select user_id from public.notes)
    order by id`)).rows;
  const snapshot = {
    format: 'tweak-supabase-snapshot', version: 1,
    exported_at: new Date().toISOString(), owners, tables,
  };
  const normalized = prepareSnapshot(snapshot);
  await source.query('commit');
  const filename = `supabase-${new Date().toISOString().replaceAll(/[:.]/g, '-')}.json`;
  const destination = resolve('.artifacts/migration', filename);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, `${JSON.stringify(snapshot, null, 2)}\n`, { flag: 'wx', mode: 0o600 });
  console.log(JSON.stringify({ snapshot: destination, counts: normalized.counts,
    photos_copied: false, source_modified: false }, null, 2));
} catch (error) {
  if (source) await source.query('rollback').catch(() => {});
  reportError(error);
} finally { await source?.end(); }
