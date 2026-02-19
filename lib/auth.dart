import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

final supabase = Supabase.instance.client;
final GoogleSignIn googleSignIn = GoogleSignIn.instance;

/// ------------------------------
/// Sign up with email
/// ------------------------------
Future<void> signUp(String email, String password) async {
  await supabase.auth.signUp(email: email, password: password);
}

/// ------------------------------
/// Login with email
/// ------------------------------
Future<String?> signIn(String email, String password) async {
  try {
    final res = await supabase.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) return "No user found";

    // Fetch profile to get role
    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('auth_id', user.id)
        .single();

    return profile['role'];
  } catch (e) {
    return e.toString();
  }
}

/// ------------------------------
/// TODO: redirect for password reset
/// ------------------------------
Future<void> sendPasswordResetEmail(String email) async {

}

/// ------------------------------
/// Google Login
/// ------------------------------
Future<void> signInWithGoogle() async {
  try {
    await GoogleSignIn.instance.authenticate();
  } catch (e) {
    throw Exception("Google sign-in failed: $e");
  }
}

/// ------------------------------
/// Sign Out
/// ------------------------------
Future<void> signOut() async {
  await supabase.auth.signOut();
}

