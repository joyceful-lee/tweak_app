# Supabase to Neon migration

## Current state

- Neon Free resource `tweak-recipes-db` is provisioned in `iad1`, connected to the existing Vercel `tweak-recipes` project. Resource ID: `store_pdS9IVvLKy0Bexp7`.
- Neon Auth is enabled and the database connection has been verified.
- `001_recipes.sql` creates the recipe tables; `002_photos_and_mobile_login.sql` adds private photo metadata and temporary native sign-in handoffs. Row-level security is enabled without public client grants or policies. The server API enforces account ownership using the private database connection.
- The replacement website/API was promoted to **https://tweak-recipes.vercel.app/** on November 18, 2026. Deployment: `dpl_DnLEuFQCfe5WDgUMzkBS8VJZpPzf`. Its health endpoint reports Neon and private photos; unauthenticated session, recipe, and photo requests return 401.
- The updated Flutter web and Android release builds succeeded. Android installer: `build/app/outputs/flutter-apk/app-release.apk` (59,425,208 bytes). Previously installed app versions still use Supabase until updated.
- The source snapshot has been imported: **20 recipes, 29 versions, 5 notebook notes, and 3 source owners**, with IDs, dates, best-version links, and all field contents verified. No recipe-photo references were present. All 3 owners still need new Neon logins and verified ownership restoration.
- Sign-in is currently blocked by Neon Auth's trusted-origin configuration. The live API reports a clear setup error. Follow [remaining setup](REMAINING_SETUP.md); this account setting cannot be changed with the available database/integration credentials.
- Supabase has not been modified or deleted.

## Custom domain follow-up — November 18, 2026

`https://tweak.joyceful-lee.com/` is connected to the same Vercel project. The user added Cloudflare's DNS-only CNAME `tweak` → `c3c81bcc2277e692.vercel-dns-017.com`; Vercel reports no DNS misconfiguration. HTTPS, the rendered login screen, and the Neon health endpoint were verified. Production deployment `dpl_FNx3xRToqDRmdNvSmPWFG4qgvUoT` supports both app origins and keeps OAuth callbacks on the requesting app's host. All 18 Node tests passed, including custom-domain and lookalike-origin checks. The main portfolio remains on its existing host. Neon Auth must trust both exact app origins listed in `REMAINING_SETUP.md`.

## Local credentials

### Authentication diagnosis — November 18, 2026

The live Google route returned 502 because it allowed only Google's hosts, while Managed Better Auth first returns its own `/sign-in/social/init` URL. The route now accepts that exact path on the configured Neon Auth origin, while rejecting other hosts, paths, credentials, and non-HTTPS URLs. Deployment `dpl_D1phisdWbnmJHS6d4vmm1YNnZaRD` was promoted. Both public origins return 302 through Neon to Google; browser verification reached Google's account chooser. All 19 Node tests passed.

Read-only diagnosis found zero Neon accounts, both trusted origins configured, email/password enabled, shared SMTP selected, and email webhooks disabled. Forgot-password and email-verification requests for an address without a Neon account intentionally return success without sending mail. The user must create a new login or complete Google sign-in first, then restore imported recipes. Actual mailbox delivery and the signed-in callback remain user checks.

The Vercel CLI pulls Neon Development credentials into the ignored `.env.local`. Never put a PostgreSQL connection string in Dart, a web build, Git, or chat. Use the CLI with the linked project `leejoyce21-7656/tweak-recipes`. The exporter validates TLS and hostnames; `neon/certs/supabase-root-2021.crt` is the public Supabase Root 2021 CA, downloaded from Supabase's official certificate bucket for the source pooler's certificate chain.

Copy `.env.migration.example` to `.env.migration.local`. Set `SUPABASE_DATABASE_URL` locally to the Supabase PostgreSQL Session pooler URI with the actual password. Both environment files and the snapshot directory are excluded from Git and web deployment.

## Commands

```powershell
npm install --ignore-scripts
npm test
npm run db:check
npm run db:migrate
npm run db:verify
npm run db:export:supabase
node --env-file=.env.local scripts/neon/import-supabase.mjs .artifacts/migration/<snapshot>.json
node --env-file=.env.local scripts/neon/import-supabase.mjs .artifacts/migration/<snapshot>.json --apply
node --env-file=.env.local scripts/neon/audit-snapshot.mjs .artifacts/migration/<snapshot>.json
```

The export uses a consistent, read-only database transaction. It copies dishes, versions, notebook notes, and only the owner identity fields needed for account mapping. It never selects password hashes or session tokens. The app's existing JSON export is not a substitute: it does not retain all IDs and ownership fields required for a faithful migration.

Import defaults to a dry run. Applying an import writes to the new Neon database in a transaction, requires an empty target, validates relationships, retains original IDs and creation dates, and verifies counts before committing. Unexpected source fields are preserved in `legacy_payload`. A digest ledger prevents applying the same snapshot twice. It never merges over existing target recipes. SQL migrations are checksummed; changing an already-applied migration is rejected.

Snapshots contain private recipe content and owner email addresses. They remain in the ignored `.artifacts/migration` directory. Do not commit or deploy them.

## Completed verification and remaining checks

1. Final source snapshot `supabase-2026-11-18T20-29-46-359Z.json` matched the imported `supabase-2026-11-18T19-55-48-979Z.json`. A final Neon audit verified all imported fields and ownership records. If older apps make further Supabase edits, reconcile that delta separately; never truncate Neon to force a refresh.
2. Node tests: **17 passed**. Flutter tests: **10 passed**. Analyzer: no errors or warnings; one existing `onReorder` deprecation information item remains.
3. Real-database checks passed for recipe/version/note CRUD, best-version constraints, owner restoration, and cross-account denial. Temporary test writes were rolled back. RLS and schema constraints were verified.
4. A synthetic image passed the private Blob upload/read/unauthenticated-denial checks and was removed afterward. No source photo files required transfer. JSON exports retain photo references but do not back up image binaries.
5. The Flutter Supabase adapter has been replaced by the Vercel API. Web sessions use managed HttpOnly cookies, native sessions use secure storage, and Google app return uses a one-use PKCE-bound handoff. Imported-account access requires a fresh email code, verified identity, and revocation of older sessions.
6. The live login screen loads. Real-account sign-in, email delivery, Google consent, session persistence, phone/computer sync, camera/gallery permissions, recovery, and cold-start behavior remain user/device checks after the trusted-origin setting is fixed. No development check sent account verification emails.
7. Keep Supabase available for fallback until the updated app and website are verified. Retire it only after a final backup and the user's decision.

## Password accounts

Neon's current [Managed Auth migration guide](https://neon.com/docs/auth/migrate/from-supabase) says existing password accounts cannot migrate directly because the password hashing differs. Plan for a new account or OAuth sign-in, followed by verified ownership linking. The older Stack Auth migration article describes a different, legacy product and must not be used to promise password continuity.

## Recovery

An export never changes Supabase. An import failure rolls back the Neon transaction. Do not clear or truncate a non-empty target to force another import; inspect the ledger and determine whether the existing data is expected. The new website and APK target Neon; older installed apps still target Supabase. If rollback is needed after users edit Neon, preserve those new changes before returning to the old backend.
