/// ------------------------------
/// Upper-level info about a recipe (name, id, etc.)
/// ------------------------------
class Dish {
  final String id;
  final String name;
  final String description;
  final String status;
  final String? bestVersionId;
  final DishVersion? bestVersion;
  final List<DishVersion>? versions;
  final DateTime createdAt;

  Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.bestVersion,
    required this.createdAt,
    this.bestVersionId,
    this.versions = const [],
  });

  factory Dish.fromMap(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return Dish(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? '',
      bestVersionId: map['best_version']?.toString(),
      bestVersion: map['best'] != null
          ? DishVersion.fromMap(Map<String, dynamic>.from(map['best']))
          : null,
      versions: map['dish_versions'] != null
          ? (map['dish_versions'] as List)
                .map((v) => DishVersion.fromMap(Map<String, dynamic>.from(v)))
                .toList()
          : const [],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'best_version_id': bestVersionId,
      'created_at': createdAt.toIso8601String(),
      'versions': versions?.map((v) => v.toJson()).toList(),
    };
  }
}

/// ------------------------------
/// Lower-level info about a recipe (details like ingredients, etc)
/// ------------------------------
class DishVersion {
  final List<String> photoPaths;
  final String id;
  final String dishId;
  final int versionNumber;
  final List<String> ingredients;
  final List<String> directions;
  final String notes;
  final List<String> tags;
  final String status;
  final DateTime createdAt;

  DishVersion({
    this.photoPaths = const [],
    required this.id,
    required this.dishId,
    required this.versionNumber,
    required this.ingredients,
    required this.directions,
    required this.notes,
    required this.tags,
    required this.status,
    required this.createdAt,
  });

  factory DishVersion.fromMap(Map<String, dynamic> map) {
    return DishVersion(
      photoPaths: List<String>.from(map['photo_paths'] ?? []),
      id: map['id'].toString(),
      dishId: map['dish_id'].toString(),
      versionNumber: map['version_number'] ?? 1,
      ingredients: List<String>.from(map['ingredients'] ?? []),
      directions: List<String>.from(map['directions'] ?? []),
      notes: map['notes'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      status: map['status'] ?? 'in_testing',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  factory DishVersion.fromJson(Map<String, dynamic> json) {
    return DishVersion(
      photoPaths: List<String>.from(json['photo_paths'] ?? []),
      id: json['id'].toString(),
      dishId: json['dish_id'].toString(),
      versionNumber: json['version_number'] ?? 1,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      directions: List<String>.from(json['directions'] ?? []),
      notes: json['notes'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      status: json['status'] ?? 'in_testing',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dish_id': dishId,
      'photo_paths': photoPaths,
      'version_number': versionNumber,
      'ingredients': ingredients,
      'directions': directions,
      'notes': notes,
      'tags': tags,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
