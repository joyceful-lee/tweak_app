import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'http_factory.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

typedef AuthException = ApiException;

enum AuthChangeEvent { initialSession, signedIn, signedOut, passwordRecovery }

class AppUser {
  final String id;
  final String? email;
  final bool emailVerified;
  const AppUser({required this.id, this.email, this.emailVerified = false});
  factory AppUser.fromMap(Map<String, dynamic> data) => AppUser(
    id: data['id'] as String,
    email: data['email'] as String?,
    emailVerified: data['emailVerified'] == true,
  );
}

class AuthState {
  final AuthChangeEvent event;
  const AuthState(this.event);
}

class BackendClient {
  static final instance = BackendClient();
  final http.Client _http;
  final FlutterSecureStorage _storage;
  final _changes = StreamController<AuthState>.broadcast();
  String? _session;
  AppUser? currentUser;
  int accountRevision = 0;
  StreamSubscription<Uri>? _links;
  final String? baseUrlOverride;
  BackendClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    this.baseUrlOverride,
  }) : _http = client ?? createHttpClient(),
       _storage = storage ?? const FlutterSecureStorage();
  Stream<AuthState> get authChanges => _changes.stream;
  String get baseUrl =>
      baseUrlOverride ??
      (kIsWeb
          ? Uri.base.origin
          : const String.fromEnvironment(
              'TWEAK_API_URL',
              defaultValue: 'https://tweak-recipes.vercel.app',
            ));
  Map<String, String> get imageHeaders =>
      !kIsWeb && _session != null ? {'Authorization': 'Bearer $_session'} : {};
  String photoUrl(String id) =>
      '$baseUrl/api/photos/${Uri.encodeComponent(id)}';
  Future<void> initialize() async {
    if (!kIsWeb) {
      _session = await _storage.read(key: 'tweak.neon.session');
      final appLinks = AppLinks();
      _links = appLinks.uriLinkStream.listen((uri) {
        _handleLink(uri).catchError((Object e) {
          debugPrint('Sign-in link could not be completed.');
        });
      });
      final initial = await appLinks.getInitialLink();
      if (initial != null) await _handleLink(initial);
    }
    try {
      await refreshSession();
    } catch (_) {
      /* Sign-in supports retrying after network errors. */
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    Uint8List? bytes,
    String? contentType,
  }) async {
    final req = http.Request(method, Uri.parse('$baseUrl/api/$path'));
    req.headers.addAll(imageHeaders);
    if (!kIsWeb) req.headers['X-Tweak-Client'] = 'native';
    if (bytes != null) {
      req.bodyBytes = bytes;
      req.headers['Content-Type'] = contentType ?? 'application/octet-stream';
    } else if (body != null) {
      req.body = jsonEncode(body);
      req.headers['Content-Type'] = 'application/json';
    }
    final response = await http.Response.fromStream(
      await _http.send(req).timeout(const Duration(seconds: 45)),
    );
    dynamic data;
    try {
      data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      throw const ApiException(
        'The website returned an unexpected response. Please try again.',
      );
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && currentUser != null) {
        currentUser = null;
        _changes.add(const AuthState(AuthChangeEvent.signedOut));
      }
      throw ApiException(
        data is Map
            ? (data['message'] ?? 'Request failed.').toString()
            : 'Request failed.',
        response.statusCode,
      );
    }
    if (!kIsWeb && data is Map && data['mobileSession'] is String) {
      _session = data['mobileSession'];
      await _storage.write(key: 'tweak.neon.session', value: _session);
    }
    return data;
  }

  Future<void> refreshSession() async {
    try {
      final data = await request('GET', 'session');
      currentUser = AppUser.fromMap(Map<String, dynamic>.from(data['user']));
      _changes.add(const AuthState(AuthChangeEvent.signedIn));
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
      currentUser = null;
      _changes.add(const AuthState(AuthChangeEvent.signedOut));
    }
  }

  Future<void> signIn(String email, String password) async {
    await request(
      'POST',
      'auth/sign-in/email',
      body: {'email': email, 'password': password},
    );
    await refreshSession();
  }

  Future<void> signUp(String email, String password) async {
    await request(
      'POST',
      'auth/sign-up/email',
      body: {
        'email': email,
        'password': password,
        'name': email.split('@').first,
      },
    );
    await refreshSession();
  }

  Future<void> signOut() async {
    await request('POST', 'auth/sign-out', body: {});
    _session = null;
    currentUser = null;
    if (!kIsWeb) await _storage.delete(key: 'tweak.neon.session');
    _changes.add(const AuthState(AuthChangeEvent.signedOut));
  }

  Future<void> googleSignIn() async {
    Uri url;
    if (kIsWeb) {
      url = Uri.parse('$baseUrl/api/auth/google');
    } else {
      final random = Random.secure();
      final verifier = base64UrlEncode(
        List.generate(32, (_) => random.nextInt(256)),
      ).replaceAll('=', '');
      final data = await request(
        'POST',
        'auth/mobile/start',
        body: {'challenge': sha256.convert(utf8.encode(verifier)).toString()},
      );
      url = Uri.parse(data['url']);
      await _storage.write(
        key: 'tweak.neon.pendingLogin',
        value: jsonEncode({
          'request': url.queryParameters['mobile'],
          'verifier': verifier,
        }),
      );
    }
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    )) {
      throw const ApiException('Could not open Google sign-in.');
    }
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.scheme != 'com.tweakapp' || uri.host != 'login') return;
    final pending = await _storage.read(key: 'tweak.neon.pendingLogin');
    if (pending == null) return;
    final values = jsonDecode(pending) as Map<String, dynamic>;
    if (values['request'] != uri.queryParameters['request']) {
      throw const ApiException('Sign-in link does not match this device.');
    }
    await request(
      'POST',
      'auth/mobile/exchange',
      body: {...values, 'code': uri.queryParameters['code']},
    );
    await _storage.delete(key: 'tweak.neon.pendingLogin');
    await refreshSession();
  }

  void notifyAccountChanged() {
    accountRevision++;
    _changes.add(const AuthState(AuthChangeEvent.signedIn));
  }

  Future<void> dispose() async {
    await _links?.cancel();
    _http.close();
    await _changes.close();
  }
}
