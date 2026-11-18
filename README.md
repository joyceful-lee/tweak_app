# Tweak

Recipe version control for phone and computer, built with Flutter, Neon PostgreSQL, Neon Auth, and private Vercel Blob photo storage.

Website: https://tweak.joyceful-lee.com/ (also available at https://tweak-recipes.vercel.app/).

## Finish account setup

See [remaining setup and device checks](docs/REMAINING_SETUP.md). Both website origins are configured in Neon Auth. Existing Supabase passwords do not transfer. Create a new login with the same email or use Google, then use the in-app restoration code flow to recover your imported recipes. Password reset and verification emails require that new account to exist first.

The imported data is verified: **20 recipes, 29 versions, 5 notes, 3 owners**. Supabase is retained as a backup. The new app does not use Supabase keys, Auth, database APIs, or Storage.

## Local development

- Flutter 3.47.6 / Dart 3.13.5 was used for verification.
- Node.js 22 or newer.
- Run `flutter pub get` and `npm ci --ignore-scripts`.
- This checkout is linked to Vercel project `leejoyce21-7656/tweak-recipes` (`prj_ixusWu2yz7JIRjuiM7GX1EJdFJxa`). Pull Development environment variables with `vercel env pull .env.local --yes`. Never print or commit their values.
- Run `flutter build web --release --no-wasm-dry-run`, then `npm run dev`. Open http://127.0.0.1:8080/ for the website and API on one origin. Add a local origin to Neon Auth only if you need local real-account sign-in.
- Phone builds use https://tweak-recipes.vercel.app by default. Override with `--dart-define=TWEAK_API_URL=https://your-host` when needed. PostgreSQL credentials never belong in Dart.

## Checks and deployment

```powershell
npm test
node --env-file=.env.local scripts/neon/verify-api.mjs
flutter test
flutter analyze --no-fatal-infos
flutter build web --release --no-wasm-dry-run
flutter build apk --release
vercel deploy --prod
```

Vercel builds the Node API in `api/index.mjs` and serves the locally compiled `build/web` folder. Build Flutter before deploying; the remote build does not install Flutter. `.vercelignore` restricts uploads to the web bundle, API, server modules, and package manifests. Local secrets, migration snapshots, source database passwords, and mobile signing material are excluded.

## Photos and sign-in

Photos are private, authenticated through the API, and limited to 10 per recipe version and 4 MB each (JPEG, PNG, WebP). Images are resized by the picker when supported. New versions can share existing photos; removing one reference does not delete files used by older versions. Unsaved uploads are cleaned up when possible. JSON exports contain photo references, not image binaries.

Neon's managed auth toolkit handles password, OTP, OAuth, signed cookies, and OAuth verifier processing. Browser sessions use HttpOnly cookies; native sessions use device secure storage. Native Google sign-in returns through a short-lived, one-use, PKCE-bound handoff. Imported-account restoration requires a fresh email sign-in code and revokes older sessions before granting access.

The prior account-delete button only signed users out. It has been removed rather than presenting a misleading permanent-deletion action; account deletion currently requires an administrator in Neon.

See [migration runbook](docs/NEON_MIGRATION.md) for snapshots, verification, and rollback notes. Legacy Supabase configuration files are retained only for rollback and are not imported by the app.
