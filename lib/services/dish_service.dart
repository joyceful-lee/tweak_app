import 'backend_client.dart';
import '../models/dish.dart';

class DishService {
  final BackendClient client;
  DishService([BackendClient? client])
    : client = client ?? BackendClient.instance;
  Future<void> createDish({
    required String name,
    required String description,
    required String status,
    required List<String> ingredients,
    required List<String> directions,
    required String notes,
    required List<String> tags,
    List<String> photoPaths = const [],
  }) async {
    await client.request(
      'POST',
      'dishes',
      body: {
        'name': name,
        'description': description,
        'status': status,
        'ingredients': ingredients,
        'directions': directions,
        'notes': notes,
        'tags': tags,
        'photo_paths': photoPaths,
      },
    );
  }

  Future<List<Dish>> _fetch(String path) async =>
      (await client.request('GET', path) as List)
          .map((value) => Dish.fromMap(Map<String, dynamic>.from(value)))
          .toList();
  Future<List<Dish>> fetchDishes() => _fetch('dishes');
  Future<List<Dish>> fetchAllDishesFull() => _fetch('dishes/export');
  Future<List<DishVersion>> fetchDishVersions(String id) async =>
      (await client.request('GET', 'dishes/$id/versions') as List)
          .map((value) => DishVersion.fromMap(Map<String, dynamic>.from(value)))
          .toList();
  Future<Map<String, dynamic>> fetchDishById(String id) async =>
      Map<String, dynamic>.from(await client.request('GET', 'dishes/$id'));
  Future<void> updateDishStatus({
    required String dishId,
    required String status,
  }) async {
    await client.request('PATCH', 'dishes/$dishId', body: {'status': status});
  }

  Future<void> deleteDish(String id) async {
    await client.request('DELETE', 'dishes/$id');
  }

  Future<void> updateDishVersion({
    required String versionId,
    required List<String> ingredients,
    required List<String> directions,
    required String notes,
    required List<String> tags,
    List<String>? photoPaths,
  }) async {
    await client.request(
      'PATCH',
      'versions/$versionId',
      body: {
        'ingredients': ingredients,
        'directions': directions,
        'notes': notes,
        'tags': tags,
        'photo_paths': photoPaths ?? [],
      },
    );
  }

  Future<Map<String, dynamic>> addDishVersion(
    String id, {
    required String baseVersionId,
    required List<String> ingredients,
    required List<String> directions,
    required String notes,
    required List<String> tags,
    List<String>? photoPaths,
  }) async => Map<String, dynamic>.from(
    await client.request(
      'POST',
      'dishes/$id/versions',
      body: {
        'base_version_id': baseVersionId,
        'ingredients': ingredients,
        'directions': directions,
        'notes': notes,
        'tags': tags,
        'photo_paths': photoPaths ?? [],
      },
    ),
  );
  Future<void> deleteVersion(String dishId, String versionId) async {
    await client.request('DELETE', 'versions/$versionId');
  }

  Future<void> updateBestVersion(String dishId, String versionId) async {
    await client.request(
      'PATCH',
      'dishes/$dishId/best',
      body: {'version_id': versionId},
    );
  }
}
