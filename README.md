# Tweak

Recipe version-control app built with Flutter and Supabase.

## Local setup

Copy `lib/config/supabase_config.example.dart` to `lib/config/supabase_config.dart`, then supply the project URL, anon key, and `redirectUrl`.

Use `com.tweakapp://reset-password` as `redirectUrl`. Add that exact URL to Supabase Auth's redirect allow list. The Android and iOS app registrations both use the `com.tweakapp` URL scheme.

## Database follow-up

Recipe version creation and deletion currently call multiple client-side database operations. Before production, move them to transactional Supabase RPCs and enforce a unique database constraint on `(dish_id, version_number)`. This prevents concurrent version-number collisions and partial deletes.
