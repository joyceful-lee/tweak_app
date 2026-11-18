import 'services/backend_client.dart';
export 'services/backend_client.dart'
    show AuthState, AuthChangeEvent, AuthException, ApiException;

final backend = BackendClient.instance;
Future<void> signUp(String email, String password) =>
    backend.signUp(email, password);
Future<void> signIn(String email, String password) =>
    backend.signIn(email, password);
Future<void> signOut() => backend.signOut();
Future<void> signInWithGoogle() => backend.googleSignIn();
Future<void> sendPasswordResetEmail(String email) async {
  await backend.request(
    'POST',
    'auth/email-otp/send-verification-otp',
    body: {'email': email, 'type': 'forget-password'},
  );
}

Future<void> resetPasswordWithCode(
  String email,
  String code,
  String password,
) async {
  await backend.request(
    'POST',
    'auth/email-otp/reset-password',
    body: {'email': email, 'otp': code, 'password': password},
  );
}

Future<void> updateEmail(String email) async {
  await backend.request(
    'POST',
    'auth/change-email',
    body: {'newEmail': email, 'callbackURL': '${backend.baseUrl}/'},
  );
}

Future<void> updatePassword(
  String password, {
  required String currentPassword,
}) async {
  await backend.request(
    'POST',
    'auth/change-password',
    body: {
      'newPassword': password,
      'currentPassword': currentPassword,
      'revokeOtherSessions': true,
    },
  );
}

Future<void> sendVerificationCode(String email) async {
  await backend.request(
    'POST',
    'auth/email-otp/send-verification-otp',
    body: {'email': email, 'type': 'email-verification'},
  );
}

Future<void> verifyEmailCode(String email, String code) async {
  await backend.request(
    'POST',
    'auth/email-otp/verify-email',
    body: {'email': email, 'otp': code},
  );
  await backend.refreshSession();
}
