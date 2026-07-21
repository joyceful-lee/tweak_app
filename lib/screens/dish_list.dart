import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models/dish.dart';
import '../services/dish_service.dart';
import 'add_dish_screen.dart';
import 'dish_versions.dart';
import 'dish_notes.dart';

final supabase = Supabase.instance.client;

enum DishStatus { completed, inProgress, abandoned }

DishStatus _statusFromString(String status) {
  switch (status) {
    case "finalized":
      return DishStatus.completed;
    case "finished":
      return DishStatus.completed;
    case "abandoned":
      return DishStatus.abandoned;
    case "in_testing":
      return DishStatus.inProgress;
    case "in_progress":
      return DishStatus.inProgress;
    default:
      return DishStatus.inProgress;
  }
}

class _StatusMeta {
  final String label;
  final Color dot;
  final Color pillBg;
  final Color pillText;
  const _StatusMeta(this.label, this.dot, this.pillBg, this.pillText);
}

_StatusMeta _statusMeta(DishStatus status, ColorScheme cs) {
  switch (status) {
    case DishStatus.completed:
      return _StatusMeta(
        "Completed",
        cs.secondary,
        cs.secondary,
        cs.onSecondary,
      );
    case DishStatus.inProgress:
      return _StatusMeta(
          "In progress",
          cs.primary,
          cs.primary,
          cs.onPrimary);
    case DishStatus.abandoned:
      return _StatusMeta(
        "Abandoned",
        cs.onSurface.withValues(alpha: 0.4),
        cs.tertiary,
        cs.onTertiary,
      );
  }
}

/// Rough category icon based on tags — purely cosmetic, tweak the keyword
/// list as your tag vocabulary grows.
IconData _iconForTags(List<String> tags) {
  final joined = tags.join(' ').toLowerCase();

  const iconMappings = <List<String>, IconData>{
    ['blended']: Icons.blender_outlined,
    ['bread', 'loaf']: Icons.breakfast_dining_outlined,
    ['burger', 'burgers', 'sandwich', 'sandwiches']: Icons.lunch_dining_outlined,
    ['cake', 'birthday']: Icons.cake_outlined,
    ['cookie']: Icons.cookie_outlined,
    ['croissant', 'pastry']: Icons.bakery_dining_outlined,
    ['coffee']: Icons.local_cafe_outlined,
    ['cocktail', 'boozy']: Icons.local_bar_outlined,
    ['eggs', 'egg']: Icons.egg_alt_outlined,
    ['floral', 'flower']: Icons.local_florist_outlined,
    ['frozen']: Icons.ac_unit,
    ['grilled']: Icons.outdoor_grill_outlined,
    ['healthy']: Icons.eco_outlined,
    ['honey']: Icons.hive_outlined,
    ['ice cream', 'gelato']: Icons.icecream_outlined,
    ['mocktail', 'non-alcoholic']: Icons.no_drinks_outlined,
    ['pasta']: Icons.dinner_dining_outlined,
    ['pizza']: Icons.local_pizza_outlined,
    ['ramen', 'noodles', 'udon']: Icons.ramen_dining_outlined,
    ['rice']: Icons.rice_bowl_outlined,
    ['seafood', 'fish']: Icons.set_meal_outlined,
    ['skewers', 'barbecue', 'bbq']: Icons.kebab_dining_outlined,
    ['soup', 'broth']: Icons.soup_kitchen_outlined,
    ['sparkling', 'spritzer']: Icons.bubble_chart_outlined,
    ['spicy']: Icons.local_fire_department_outlined,
    ['syrup']: Icons.water_drop_outlined,
    ['tea']: Icons.emoji_food_beverage_outlined,
    ['wine']: Icons.wine_bar_outlined,
    ['beer']: Icons.sports_bar_outlined,
    ['liquor']: Icons.liquor_outlined,
  };

  for (final entry in iconMappings.entries) {
    if (entry.key.any(joined.contains)) {
      return entry.value;
    }
  }

  return Icons.restaurant_menu_outlined;
}

/// ------------------------------
/// Dish List Screen
/// ------------------------------
class DishListScreen extends StatefulWidget {
  const DishListScreen({super.key});

  @override
  State<DishListScreen> createState() => _DishListScreenState();
}

class _DishListScreenState extends State<DishListScreen> {
  final DishService _dishService = DishService(supabase);

  List<Dish> _dishes = [];
  bool _isLoading = true;
  String? _selectedDishId;
  DishStatus? _filter; // null = "All"
  StreamSubscription<AuthState>? _authSubscription;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String? _selectedTag;
  bool _sortByAlpha = false;

  @override
  void initState() {
    super.initState();
    if (supabase.auth.currentUser != null) {
      _loadDishes();
    }

    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
      }
    });

    // Listen for auth changes and reload dishes when a user signs in
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) {
        if (Supabase.instance.client.auth.currentUser != null) {
          _loadDishes();
        } else {
          if (mounted) setState(() => _dishes = []);
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDishes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dishes = await _dishService.fetchDishes();
      if (!mounted) return;
      setState(() => _dishes = dishes);

      // If selected dish was deleted/removed, clear selection
      if (_selectedDishId != null &&
          !_dishes.any((d) => d.id == _selectedDishId)) {
        _selectedDishId = null;
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR: $e');
      debugPrint('STACKTRACE:\n$stackTrace');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAndDeleteSelected() async {
    final dishId = _selectedDishId;
    if (dishId == null) return;

    final dish = _dishes.firstWhere((d) => d.id == dishId);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete dish?"),
        content: Text(
          "This will permanently delete “${dish.name}” and all its versions.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await _dishService.deleteDish(dishId);
      if (!mounted) return;

      setState(() => _selectedDishId = null);
      await _loadDishes();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Dish deleted")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  List<Dish> get _visibleDishes {
    var list = _dishes;

    // 1. Status Filter
    if (_filter != null) {
      list = list
          .where((d) => _statusFromString(d.status) == _filter)
          .toList();
    }

    // 2. Tag Filter
    if (_selectedTag != null) {
      list = list.where((d) {
        final tags = d.bestVersion?.tags ?? [];
        return tags.contains(_selectedTag);
      }).toList();
    }

    // 3. Search Query (Name or Tags)
    if (_searchQuery.isNotEmpty) {
      list = list.where((d) {
        final nameMatch = d.name.toLowerCase().contains(_searchQuery);

        final tags = d.bestVersion?.tags ?? [];
        final tagMatch = tags.any(
          (tag) => tag.toLowerCase().contains(_searchQuery),
        );

        return nameMatch || tagMatch;
      }).toList();
    }

    // 4. Sorting
    if (_sortByAlpha) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // Default: Sort by created_at descending (newest first)
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return list;
  }

  Widget _buildSearchBar(ColorScheme cs) {
    // Extract unique tags from all dishes
    final allTags = _dishes
        .expand((d) => d.bestVersion?.tags ?? <String>[])
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontFamily: kBodyFont, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search dishes or tags...",
                prefixIcon: Icon(Icons.search, color: cs.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                    : null,
                filled: true,
                fillColor: cs.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          MenuAnchor(
            builder: (context, controller, child) {
              return Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: (_selectedTag != null || _sortByAlpha)
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                ),
              );
            },
            menuChildren: [
              MenuItemButton(
                onPressed: () => setState(() => _sortByAlpha = !_sortByAlpha),
                leadingIcon: Icon(
                  _sortByAlpha ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: cs.primary,
                ),
                child: const Text("Sort A-Z"),
              ),
              const PopupMenuDivider(),
              if (allTags.isEmpty)
                MenuItemButton(
                  onPressed: null,
                  child: const Text("No tags found"),
                )
              else ...[
                MenuItemButton(
                  onPressed: _selectedTag == null ? null : () => setState(() => _selectedTag = null),
                  child: Text(
                    "Clear Tag Filter",
                    style: TextStyle(
                      color: _selectedTag != null ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
                ...allTags.map(
                  (tag) => MenuItemButton(
                    onPressed: () => setState(() => _selectedTag = tag),
                    leadingIcon: _selectedTag == tag
                        ? Icon(Icons.check, size: 18, color: cs.primary)
                        : const SizedBox(width: 18),
                    child: Text(tag),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme cs) {
    Widget chip(String label, DishStatus? value) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              fontFamily: kBodyFont,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: selected ? cs.surface : cs.onSurface,
            ),
          ),
          selected: selected,
          onSelected: (_) => setState(() => _filter = value),
          selectedColor: cs.onSurface,
          backgroundColor: cs.surface,
          side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip("All", null),
            chip("In progress", DishStatus.inProgress),
            chip("Completed", DishStatus.completed),
            chip("Abandoned", DishStatus.abandoned),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(List<String> tags, ColorScheme cs) {
    const maxShown = 2;
    final shown = tags.take(maxShown).toList();
    final overflow = tags.length - shown.length;

    Widget pill(String text, {bool muted = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: cs.onTertiaryFixedVariant.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kBodyFont,
          fontSize: 11,
          color: muted ? cs.onSurface.withValues(alpha: 0.3) : cs.onSurface,
          fontVariations: [
            FontVariation('wght', 300),
          ],
        ),
      ),
    );

    return Row(
      children: [
        ...shown.map((t) => pill(t)),
        if (overflow > 0) pill("+$overflow", muted: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selectedDishId != null;
    final cs = Theme.of(context).colorScheme;
    final dishes = _visibleDishes;

    return Scaffold(
      backgroundColor: cs.onTertiaryFixedVariant,
      appBar: AppBar(
        title: Text("Tweak", style: TextStyle(fontFamily: kTitleFont)),
        backgroundColor: cs.inverseSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Logout"),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await Supabase.instance.client.auth.signOut();
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: hasSelection
          ? SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text("Delete Dish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: TextStyle(
                  fontFamily: kHeadingFont,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _confirmAndDeleteSelected,
            ),
          ),
        ),
      )
          : null,

      body: Column(
        children: [
          _buildSearchBar(cs),
          _buildFilterBar(cs),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : dishes.isEmpty
                ? Center(
              child: Text(
                _filter == null ? "No dishes yet." : "No dishes here.",
                style: TextStyle(fontFamily: kBodyFont),
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadDishes,
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: hasSelection ? 90 : 12),
                itemCount: dishes.length,
                itemBuilder: (context, index) {
                  final dish = dishes[index];
                  final bestVersion = dish.bestVersion;
                  final isSelected = dish.id == _selectedDishId;
                  final status = _statusFromString(dish.status);
                  final meta = _statusMeta(status, cs);
                  final tags = bestVersion?.tags ?? const <String>[];

                  return Card(
                    color: isSelected
                        ? Colors.red.withValues(alpha: 0.08)
                        : cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? const BorderSide(
                        color: Colors.red,
                        width: 1.2,
                      )
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        if (_selectedDishId != null) {
                          setState(() {
                            _selectedDishId = isSelected ? null : dish.id;
                          });
                          return;
                        }

                        final action = await showModalBottomSheet<String>(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.layers),
                                  title: const Text("View Versions"),
                                  onTap: () =>
                                      Navigator.pop(context, "versions"),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.sticky_note_2,
                                  ),
                                  title: const Text(
                                    "View Notes (all versions)",
                                  ),
                                  onTap: () =>
                                      Navigator.pop(context, "notes"),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (!mounted || action == null) return;
                        if (action == "versions") {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DishVersionsScreen(
                                dish: dish,
                                dishService: _dishService,
                              ),
                            ),
                          );
                          _loadDishes();
                          return;
                        }

                        if (action == "notes") {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DishAllNotesScreen(
                                dish: dish,
                                dishService: _dishService,
                              ),
                            ),
                          );
                          _loadDishes();
                          return;
                        }
                      },
                      onLongPress: () {
                        setState(() {
                          _selectedDishId = isSelected ? null : dish.id;
                        });
                      },
                      child: Opacity(
                        opacity: status == DishStatus.abandoned
                            ? 0.7
                            : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail with status dot
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: cs.tertiary.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                    child: Icon(
                                      _iconForTags(tags),
                                      color: cs.inverseSurface,
                                      size: 26,
                                    ),
                                  ),
                                  Positioned(
                                    top: -3,
                                    right: -3,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: meta.dot,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: cs.surface,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Text content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dish.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: kHeadingFont,
                                        fontSize: 17,
                                        fontVariations: [
                                          FontVariation('wght', 800),
                                        ],
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: meta.pillBg,
                                            borderRadius:
                                            BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            meta.label,
                                            style: TextStyle(
                                              fontFamily: kBodyFont,
                                              fontSize: 11,
                                              fontVariations: [
                                                FontVariation('wght', 800),
                                              ],
                                              color: meta.pillText,
                                            ),
                                          ),
                                        ),
                                        if (bestVersion != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            "v${bestVersion.versionNumber}",
                                            style: TextStyle(
                                              fontFamily: kBodyFont,
                                              fontSize: 12,
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (tags.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      _buildTags(tags, cs),
                                    ],
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                        ),
                                        child: Text(
                                          "Selected — tap Delete Dish below",
                                          style: TextStyle(
                                            fontFamily: kBodyFont,
                                            color: Colors.red,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDishScreen(dishService: _dishService),
            ),
          ).then((_) => _loadDishes());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
