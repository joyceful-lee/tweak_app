import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dish.dart';
import '../services/dish_service.dart';
import 'add_dish_screen.dart';
import 'dish_versions.dart';
import 'dish_notes.dart';

final supabase = Supabase.instance.client;

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

  @override
  void initState() {
    super.initState();
    if (supabase.auth.currentUser != null) {
      _loadDishes();
    }
  }

  Future<void> _loadDishes() async {
    setState(() => _isLoading = true);
    try {
      final dishes = await _dishService.fetchDishes();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dish deleted")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  /// ------------------------------
  /// Add icons to the card for easy viewing
  /// ------------------------------
  String _statusIcon(String status) {
    if (status == "finalized" || status == "finished") return '🟢';
    if (status == "in_testing") return '🟡';
    return '🔴';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selectedDishId != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tweak"),
        backgroundColor: cs.onSurface,
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
                textStyle: const TextStyle(
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

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dishes.isEmpty
          ? const Center(child: Text("No dishes yet."))
          : RefreshIndicator(
        onRefresh: _loadDishes,
        child: ListView.builder(
          padding: EdgeInsets.only(
            bottom: hasSelection ? 90 : 12, // space for bottom bar
          ),
          itemCount: _dishes.length,
          itemBuilder: (context, index) {
            final dish = _dishes[index];
            final bestVersion = dish.bestVersion;
            final isSelected = dish.id == _selectedDishId;

            final icon = _statusIcon(dish.status);

            return Card(
              color: isSelected ? Colors.red.withValues(alpha:0.08) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSelected
                    ? const BorderSide(color: Colors.red, width: 1.2)
                    : BorderSide.none,
              ),
              child: ListTile(
                onTap: () async {
                  // If something is selected, tapping toggles selection instead of navigating.
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
                            onTap: () => Navigator.pop(context, "versions"),
                          ),
                          ListTile(
                            leading: const Icon(Icons.sticky_note_2),
                            title: const Text("View Notes (all versions)"),
                            onTap: () => Navigator.pop(context, "notes"),
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
                        builder: (_) => DishAllNotesScreen(dish: dish, dishService: _dishService),
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
                title: Row(
                  children: [
                    Text(
                      "$icon ${dish.name}",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (bestVersion != null) ...[
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bestVersion != null)
                      Text("Best Version: v${bestVersion.versionNumber}",
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.inverseSurface,
                        ),
                      ),
                    if (bestVersion != null)
                      Text("Tags: ${bestVersion.tags.join(', ')}",
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.inverseSurface,
                        ),
                      ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          "Selected — tap Delete Dish below",
                          style: TextStyle(
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton(
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
