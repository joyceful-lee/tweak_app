import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { connectDatabase, reportError } from './db.mjs';

let db;
try {
  db = await connectDatabase();
  await db.query('begin');
  await db.query("select pg_advisory_xact_lock(hashtext('tweak:schema-migration'))");
  const { rows: [existing] } = await db.query(`select
    to_regclass('tweak_migrations.schema_history') is not null as tracked,
    (to_regclass('public.dishes') is not null or to_regclass('public.dish_versions') is not null
      or to_regclass('public.notes') is not null) as has_recipe_tables`);
  if (!existing.tracked && existing.has_recipe_tables) {
    throw new Error('Untracked recipe tables already exist in this database; refusing to modify them.');
  }
  await db.query(`create schema if not exists tweak_migrations;
    revoke all on schema tweak_migrations from public;
    create table if not exists tweak_migrations.schema_history (
      name text primary key, sha256 text not null, applied_at timestamptz not null default now()
    )`);
  const directory = new URL('../../neon/migrations/', import.meta.url);
  const files = (await readdir(directory)).filter(name => /^\d+.*\.sql$/.test(name)).sort();
  for (const name of files) {
    const sql = await readFile(new URL(name, directory), 'utf8');
    const hash = createHash('sha256').update(sql).digest('hex');
    const { rows } = await db.query('select sha256 from tweak_migrations.schema_history where name = $1', [name]);
    if (rows.length) {
      if (rows[0].sha256 !== hash) throw new Error(`Applied migration changed: ${name}`);
      console.log(`Already applied: ${name}`);
      continue;
    }
    await db.query(sql);
    await db.query('insert into tweak_migrations.schema_history (name, sha256) values ($1, $2)', [name, hash]);
    console.log(`Applied: ${name}`);
  }
  await db.query('commit');
  console.log('Neon staging schema ready. Client access remains disabled.');
} catch (error) {
  if (db) await db.query('rollback').catch(() => {});
  reportError(error);
} finally { await db?.end(); }
