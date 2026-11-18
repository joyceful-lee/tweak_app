import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tweak_app/models/dish.dart';
import 'package:tweak_app/services/recipe_photo_service.dart';

void main() {
  test('existing recipe versions without photos still load', () {
    final version = DishVersion.fromMap({'id': 'v1', 'dish_id': 'd1'});
    expect(version.photoPaths, isEmpty);
  });

  test('photo storage paths survive recipe export and import', () {
    final version = DishVersion.fromMap({
      'id': 'v1',
      'dish_id': 'd1',
      'photo_paths': ['owner/photo.jpg'],
    });
    expect(DishVersion.fromJson(version.toJson()).photoPaths, [
      'owner/photo.jpg',
    ]);
  });

  test('rejects misleading image filename and unsupported data', () async {
    final file = XFile.fromData(
      Uint8List.fromList('not an image'.codeUnits),
      name: 'photo.jpg',
      mimeType: 'image/jpeg',
    );
    await expectLater(
      RecipePhotoService.readPhoto(file),
      throwsFormatException,
    );
  });

  test('recognizes supported image signatures', () {
    expect(
      RecipePhotoService.contentType(Uint8List.fromList([255, 216, 255])),
      'image/jpeg',
    );
    expect(
      RecipePhotoService.contentType(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ),
      'image/png',
    );
    expect(
      RecipePhotoService.contentType(
        Uint8List.fromList('RIFF1234WEBP'.codeUnits),
      ),
      'image/webp',
    );
    expect(
      () => RecipePhotoService.contentType(Uint8List(0)),
      throwsFormatException,
    );
  });

  test('rejects files over the storage size limit before upload', () async {
    final file = XFile.fromData(
      Uint8List(RecipePhotoService.maxBytes + 1),
      name: 'photo.png',
    );
    await expectLater(
      RecipePhotoService.readPhoto(file),
      throwsFormatException,
    );
  });
}
