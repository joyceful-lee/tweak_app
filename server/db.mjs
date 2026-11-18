import pg from 'pg';
import { attachDatabasePool } from '@vercel/functions';

let pool;
export function database() {
  if (!pool) {
    if (!process.env.DATABASE_URL) throw new Error('Database configuration missing');
    const uri = new URL(process.env.DATABASE_URL);
    for (const key of ['sslmode','sslcert','sslrootcert','sslkey','channel_binding']) uri.searchParams.delete(key);
    pool = new pg.Pool({ connectionString: uri.toString(), ssl: { rejectUnauthorized: true },
      max: 5, idleTimeoutMillis: 5000, connectionTimeoutMillis: 15000, statement_timeout: 30000 });
    attachDatabasePool(pool);
  }
  return pool;
}
export async function transaction(action) {
  const client = await database().connect();
  try { await client.query('begin'); const result = await action(client); await client.query('commit'); return result; }
  catch (error) { await client.query('rollback'); throw error; }
  finally { client.release(); }
}
