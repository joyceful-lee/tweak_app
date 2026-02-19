import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dish.dart';

class DishService {
  final SupabaseClient supabase;

  DishService(this.supabase);

  /// ------------------------------
  /// Create a new dish with its first version
  /// ------------------------------
  Future<void> createDish({
    required String name,
    required String description,
    required String status,
    required List<String> ingredients,
    required List<String> directions,
    required String notes,
    required List<String> tags,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await supabase.rpc(
      'create_dish_with_version',
      params: {
        'p_user_id': user.id,
        'p_name': name.trim(),
        'p_description': description.trim(),
        'p_status': status,
        'p_ingredients': ingredients,
        'p_directions': directions,
        'p_notes': notes.trim(),
        'p_tags': tags,
      },
    );
  }

  /// ------------------------------
  /// Fetch all dishes
  /// ------------------------------
  Future<List<Dish>> fetchDishes() async {
    final response = await supabase
        .from('dishes')
        .select('''
          id, name, description, status, best_version,
          best:dish_versions!dishes_best_version_fkey (
            id, dish_id, version_number, tags, directions
          )
        ''')
        .order('created_at', ascending: false);


    return (response as List)
        .map((dish) => Dish.fromMap(dish))
        .toList();
  }

  /// ------------------------------
  /// Fetch all versions of a dish
  /// ------------------------------
  Future<List<DishVersion>> fetchDishVersions(String dishId) async {
    final response = await supabase
        .from('dish_versions')
        .select()
        .eq('dish_id', dishId)
        .order('version_number');

    return (response as List)
        .map((json) => DishVersion.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// ------------------------------
  /// Fetch by ID
  /// ------------------------------
  Future<Map<String, dynamic>> fetchDishById(String dishId) async {
    final dish = await supabase
        .from('dishes')
        .select()
        .eq('id', dishId)
        .single();
    return Map<String, dynamic>.from(dish);
  }

  /// ------------------------------
  /// Update Dish Status
  /// ------------------------------
  Future<void> updateDishStatus({
    required String dishId,
    required String status,
  }) async {
    await supabase
        .from('dishes')
        .update({'status': status})
        .eq('id', dishId);
  }

  /// ------------------------------
  /// Delete a dish (and its versions)
  /// ------------------------------
  Future<void> deleteDish(String dishId) async {
    // If you have ON DELETE CASCADE on dish_versions.dish_id, you can delete only the dish.
    // This two-step approach works even without cascade.
    await supabase.from('dish_versions').delete().eq('dish_id', dishId);
    await supabase.from('dishes').delete().eq('id', dishId);
  }

  /// ------------------------------
  /// Update an existing version (NO increment)
  /// ------------------------------
  Future<void> updateDishVersion({
    required String versionId,
    required List<String> ingredients,
    required List<String> directions,
    required String notes,
    required List<String> tags,
  }) async {
    await supabase
        .from('dish_versions')
        .update({
      'ingredients': ingredients,
      'directions': directions,
      'notes': notes,
      'tags': tags,
    })
        .eq('id', versionId);
  }

  /// ------------------------------
  /// Add a new version (from the existing one)
  /// ------------------------------
  Future<Map<String, dynamic>> addDishVersion(
      String dishId, {
        required String baseVersionId,
        required List<String> ingredients,
        required List<String> directions,
        required String notes,
        required List<String> tags,
      }) async {

    // Get latest version number
    final latest = await supabase
        .from('dish_versions')
        .select('version_number')
        .eq('dish_id', dishId)
        .order('version_number', ascending: false)
        .limit(1)
        .maybeSingle();

    final nextVersionNumber =
        (latest?['version_number'] ?? 0) + 1;

    final newVersion = await supabase
        .from('dish_versions')
        .insert({
          'dish_id': dishId,
          'version_number': nextVersionNumber,
          'ingredients': ingredients,
          'directions': directions,
          'notes': notes,
          'tags': tags,
        })
        .select()
        .single();

    return newVersion;
  }

  /// ------------------------------
  /// Delete a version
  /// ------------------------------
  Future<void> deleteVersion(String dishId, String versionId) async {
    final dish = await supabase
        .from('dishes')
        .select('best_version')
        .eq('id', dishId)
        .single();

    final currentBest = dish['best_version']?.toString();

    if (currentBest == versionId) {
      await supabase
          .from('dishes')
          .update({'best_version': null})
          .eq('id', dishId);
    }

    await supabase
        .from('dish_versions')
        .delete()
        .eq('id', versionId);
  }

  /// ------------------------------
  /// Update best version
  /// ------------------------------
  Future<void> updateBestVersion(String dishId, String versionId) async {
    await supabase
        .from('dishes')
        .update({'best_version': versionId})
        .eq('id', dishId);
  }
}
