import { connectDatabase, reportError } from './db.mjs';

let db;
try {
  db = await connectDatabase();
  const { rows: [result] } = await db.query(`select
    to_regclass('neon_auth.user') is not null as auth_enabled,
    to_regclass('public.dishes') is not null as recipe_schema_present,
    to_regclass('tweak_migrations.schema_history') is not null as migration_history_present`);
  console.log(JSON.stringify({ connected: true, ...result }, null, 2));
} catch (error) { reportError(error); }
finally { await db?.end(); }
