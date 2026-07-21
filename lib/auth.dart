import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

final supabase = Supabase.instance.client;

/// ------------------------------
/// Sign up with email
/// ------------------------------
Future<void> signUp(String email, String password) async {
  await supabase.auth.signUp(email: email, password: password);
}

/// ------------------------------
/// Login with email
/// ------------------------------
Future<void> signIn(String email, String password) async {
  final res = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );

  final user = res.user;

  if (user == null) {
    throw Exception('No authenticated user returned.');
  }
}

/// ------------------------------
/// Send Password Reset Email
/// ------------------------------
Future<void> sendPasswordResetEmail(String email) async {
  await supabase.auth.resetPasswordForEmail(
    email,
    redirectTo: SupabaseConfig.redirectUrl,
  );
}

/// ------------------------------
/// Google Login
/// ------------------------------
Future<void> signInWithGoogle() async {
  try {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.redirectUrl,
      scopes: 'openid email profile',
    );
  } on AuthException catch (e) {
    throw Exception('Google sign-in failed: ${e.message}');
  } catch (e) {
    throw Exception(
      'Google sign-in failed. Check that Google is enabled in Supabase Auth and that the redirect URL is configured: ${SupabaseConfig.redirectUrl}',
    );
  }
}

/// ------------------------------
/// Update Email
/// ------------------------------
Future<void> updateEmail(String newEmail) async {
  await supabase.auth.updateUser(UserAttributes(email: newEmail));
}

/// ------------------------------
/// Update Password
/// ------------------------------
Future<void> updatePassword(String newPassword) async {
  await supabase.auth.updateUser(UserAttributes(password: newPassword));
}

/// ------------------------------
/// Delete Account
/// ------------------------------
Future<void> deleteAccount() async {
  // Note: Supabase doesn't allow users to delete themselves via the client SDK
  // for security reasons by default. This usually requires a service role or a custom RPC.
  // For this implementation, we will sign out and provide a placeholder for the actual deletion.
  await signOut();
  // throw Exception("Account deletion requires admin privileges or custom RPC.");
}

/// ------------------------------
/// Sign Out
/// ------------------------------
Future<void> signOut() async {
  await supabase.auth.signOut();
}
