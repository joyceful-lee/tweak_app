import pg from 'pg';
import { readFile } from 'node:fs/promises';
import { rootCertificates } from 'node:tls';

export async function connectDatabase({ source = false } = {}) {
  const name = source ? 'SUPABASE_DATABASE_URL' : 'DATABASE_URL_UNPOOLED';
  const value = process.env[name] || (!source && process.env.DATABASE_URL);
  if (!value) throw new Error(`Missing ${name}. Configure the ignored local environment file.`);
  let uri;
  try { uri = new URL(value); } catch { throw new Error(`${name} must be a PostgreSQL URI.`); }
  if (!['postgres:', 'postgresql:'].includes(uri.protocol)) {
    throw new Error(`${name} must be a PostgreSQL URI.`);
  }
  if (!source && !/\.(neon\.tech|neon\.build)$/.test(uri.hostname)) {
    throw new Error('The migration target must be the provisioned Neon database.');
  }
  // Explicitly retain certificate verification, regardless of URI sslmode.
  for (const key of ['sslmode', 'sslcert', 'sslkey', 'sslrootcert', 'channel_binding']) {
    uri.searchParams.delete(key);
  }
  const ssl = { rejectUnauthorized: true };
  if (source && /\.(supabase\.com|supabase\.co)$/.test(uri.hostname)) {
    // Supabase's pooler chain uses its published private CA. Limit this trust
    // anchor to Supabase source hosts and keep normal hostname verification.
    const certificate = await readFile(new URL('../../neon/certs/supabase-root-2021.crt', import.meta.url), 'utf8');
    ssl.ca = [...rootCertificates, certificate];
  }
  const client = new pg.Client({
    connectionString: uri.toString(),
    ssl,
    connectionTimeoutMillis: 15000,
    statement_timeout: 60000,
    application_name: source ? 'tweak-migration-read-only' : 'tweak-neon-migration',
  });
  await client.connect();
  return client;
}

export function reportError(error) {
  // Never print connection strings, query parameters, source records, or pg detail.
  const message = String(error.message).replace(/postgres(?:ql)?:\/\/\S+/gi, '[redacted database URI]');
  console.error(`Migration failed${error.code ? ` (${error.code})` : ''}: ${message}`);
  process.exitCode = 1;
}
