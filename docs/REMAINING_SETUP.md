# Remaining setup

The website/API is published at https://tweak.joyceful-lee.com/, the Neon data copy is verified, private photo storage is configured, and the Android release is built. No database credentials or service keys need to be copied into the app. Trusted origins are configured and the Google initiation redirect has been repaired. Create your new login in step 2 before trying password recovery or email verification.

## 1. Allow the website in Neon Auth

Open the [Neon resource in Vercel](https://vercel.com/d/dashboard/integrations/neon/icfg_gdHggwDjWZegzmDzOLJo5lwe/resources/store_pdS9IVvLKy0Bexp7), then open its Neon Console.

Under **Settings → Better Auth → Domains / Trusted origins**, add:

```text
https://tweak-recipes.vercel.app
https://tweak.joyceful-lee.com
```

Use both exact HTTPS origins above, with no wildcard. The custom domain is the website address; the existing Vercel address also supports installed Android builds. **Verified November 18: both origins are now configured.** The Vercel integration gives this workspace database access, but does not give its CLI or connector Neon Auth administration access; future domain changes require updating the Neon setting too.

Under Better Auth settings, confirm **Sign-up and Sign-in with Email** are enabled. For signup verification, use **Verification code** with the shared email provider. The app implements verification and password reset by email code, so a custom SMTP account is not required for initial testing.

The Google callback is managed by Neon. Do not point Google directly at a Flutter route. For a public production launch, configure your own Google OAuth credentials and a dedicated email provider in Neon; shared credentials are for development/testing. Follow Neon's [OAuth setup](https://neon.com/docs/auth/guides/setup-oauth) and [email OTP guide](https://neon.com/docs/auth/guides/plugins/email-otp).

## 2. Restore your account

1. Open https://tweak.joyceful-lee.com/.
2. Create a **new Neon login with the same email address** as your previous Tweak account, or use Google with that email. Supabase password hashes and login sessions were not transferred.
   **Create the login before using Forgot password or Verify email with a code.** Those two email flows require an existing Neon account. The provider returns a success response without sending an email for unknown addresses, so it does not disclose who has an account.
3. Use the restoration banner or **Settings → Restore imported recipes**.
4. Request the fresh email sign-in code and enter it. The app verifies email ownership, signs out older sessions, and links only that account's imported recipes.

Repeat for any of the other two accounts you still use. All three source accounts have verified emails, so none needs a special manual-link procedure. The migration preserved their separate ownership.

## 3. Install and test the phone app

The Android release output is `build/app/outputs/flutter-apk/app-release.apk`. Install the updated app using your normal process. An older installed version still writes to Supabase and will not sync with the new website.

On a physical phone, verify:

- Sign-in survives closing and reopening the app.
- Google sign-in returns to the app, if used; email/password and email codes are also available.
- A recipe edit on the phone appears after refreshing the website, and vice versa.
- Camera capture, gallery upload, photo removal, and denied camera permission behave correctly.
- Sign-out and password recovery work with your actual mailbox.

Do not uninstall a working release merely to get around a signing mismatch. If Android reports a conflicting signature, build with the same signing key as the installed app or follow your normal release/update process.

For **iPhone/iPad**, build and sign the updated Flutter project using Xcode on a Mac. This Windows workspace cannot produce a signed iOS release. Camera/library descriptions and the sign-in URL scheme are already configured; real-device verification is still required.

## 4. Retire Supabase after verification

Keep Supabase as a fallback until the website and updated phone app have passed the checks above. Stop editing from older Supabase-connected app versions. Once satisfied, export a final backup and decide whether to retain or delete the old project. It has not been deleted or modified by the migration.

## What was verified here

- Source and Neon field-level comparison: 20 recipes, 29 versions, 5 notes, and 3 owners; no existing photo references.
- Source data was unchanged at the final pre-deployment snapshot.
- API CRUD, version sequencing, best-version links, cross-account access denial, and rollback of test writes.
- A synthetic private photo round trip; unauthenticated download was denied and the test file was removed.
- Automated Flutter and Node tests; build and deployment results are recorded in the migration runbook.

Real-account sign-in, email delivery, Google consent, and physical-camera testing cannot be completed without your account/device interaction. No invitations or verification emails were sent by the development checks.
