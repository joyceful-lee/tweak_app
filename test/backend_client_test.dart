import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tweak_app/services/backend_client.dart';
import 'package:tweak_app/services/dish_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'recipe edits send full ordered contents and stable photo references',
    () async {
      late http.Request sent;
      final client = BackendClient(
        baseUrlOverride: 'https://example.invalid',
        client: MockClient((request) async {
          sent = request;
          return http.Response('{}', 200);
        }),
      );
      await DishService(client).updateDishVersion(
        versionId: 'version-id',
        ingredients: ['salt', 'flour'],
        directions: ['mix', 'rest'],
        notes: 'Keep text',
        tags: ['bread'],
        photoPaths: ['photo-id'],
      );
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/api/versions/version-id');
      expect(jsonDecode(sent.body), {
        'ingredients': ['salt', 'flour'],
        'directions': ['mix', 'rest'],
        'notes': 'Keep text',
        'tags': ['bread'],
        'photo_paths': ['photo-id'],
      });
      await client.dispose();
    },
  );
  test('an expired session clears the signed-in identity', () async {
    var expired = false;
    final client = BackendClient(
      baseUrlOverride: 'https://example.invalid',
      client: MockClient((request) async {
        if (expired) return http.Response('{"message":"Please sign in."}', 401);
        return http.Response(
          '{"user":{"id":"user","email":"test@example.invalid","emailVerified":true}}',
          200,
        );
      }),
    );
    await client.refreshSession();
    expect(client.currentUser?.emailVerified, true);
    expired = true;
    await client.refreshSession();
    expect(client.currentUser, isNull);
    await client.dispose();
  });
  test('unexpected deployment-login HTML produces a useful error', () async {
    final client = BackendClient(
      baseUrlOverride: 'https://example.invalid',
      client: MockClient((_) async => http.Response('<html>Login</html>', 200)),
    );
    await expectLater(
      client.request('GET', 'dishes'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('unexpected response'),
        ),
      ),
    );
    await client.dispose();
  });
}
