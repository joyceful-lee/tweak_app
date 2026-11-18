import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'backend_client.dart';

/// Photos use stable storage paths so they can be shared by recipe versions.
class RecipePhotoService {
  static const bucket = 'recipe-photos';
  static const maxPhotos = 10;
  static const maxBytes = 4 * 1024 * 1024;
  final BackendClient client;

  RecipePhotoService([BackendClient? client])
    : client = client ?? BackendClient.instance;

  static String contentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException('Choose a JPEG, PNG, or WebP photo.');
  }

  static Future<Uint8List> readPhoto(XFile file) async {
    if (await file.length() > maxBytes) {
      throw const FormatException('Photos must be 4 MB or smaller.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const FormatException('Photos must be 4 MB or smaller.');
    }
    contentType(bytes);
    return bytes;
  }

  Future<String> upload(Uint8List bytes) async {
    final userId = client.currentUser?.id;
    if (userId == null) throw StateError('Sign in before adding photos.');
    if (bytes.length > maxBytes) {
      throw const FormatException('Photo is too large.');
    }
    final response = await client.request(
      'POST',
      'photos',
      bytes: bytes,
      contentType: contentType(bytes),
    );
    return response['path'] as String;
  }

  Future<String> signedUrl(String path) async => client.photoUrl(path);
  Map<String, String> get imageHeaders => client.imageHeaders;

  /// Only call for uploads whose database save failed, never shared old photos.
  Future<void> discardUploads(List<String> paths) async {
    for (final path in paths) {
      await client.request('DELETE', 'photos/$path');
    }
  }
}
