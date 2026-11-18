import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../auth.dart';
import '../models/dish.dart';
import '../services/dish_service.dart';
import '../services/export_service.dart';
import '../services/recipe_photo_service.dart';
import '../widgets/recipe_photos.dart';

/// ------------------------------
/// Screen to edit, increment, and view recipes
/// ------------------------------
enum DishVersionMode { createNewVersion, editExisting, viewOnly }

class EditDishVersion extends StatefulWidget {
  final Dish dish;
  final DishVersion version;
  final DishVersionMode mode;
  final bool isBest;

  const EditDishVersion({
    super.key,
    required this.dish,
    required this.version,
    this.mode = DishVersionMode.createNewVersion,
    this.isBest = false,
  });

  @override
  State<EditDishVersion> createState() => _EditDishVersionState();
}

class _EditDishVersionState extends State<EditDishVersion> {
  late List<String> _ingredients;
  late List<String> _directions;
  late List<String> _tags;
  late TextEditingController _notesController;
  late TextEditingController _tagController;
  late List<String> _photoPaths;
  final List<Uint8List> _photos = [];
  late final _photoService = RecipePhotoService(backend);
  bool _isSaving = false;

  bool get _readOnly => widget.mode == DishVersionMode.viewOnly;

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.version.ingredients);
    _directions = List.from(widget.version.directions);
    _tags = List.from(widget.version.tags);
    _notesController = TextEditingController(text: widget.version.notes);
    _tagController = TextEditingController();
    _photoPaths = List.of(widget.version.photoPaths);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tagController.dispose();

    super.dispose();
  }

  void _save() async {
    if (_isSaving || _readOnly) return;
    if (_ingredients.every((s) => s.trim().isEmpty) ||
        _directions.every((s) => s.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingredients and directions cannot be empty.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    final dishService = DishService(backend);
    final uploaded = <String>[];
    try {
      for (final bytes in _photos) {
        uploaded.add(await _photoService.upload(bytes));
      }
      if (widget.mode == DishVersionMode.createNewVersion) {
        await dishService.addDishVersion(
          widget.dish.id,
          baseVersionId: widget.version.id,
          ingredients: _ingredients,
          directions: _directions,
          notes: _notesController.text,
          tags: _tags,
          photoPaths: [..._photoPaths, ...uploaded],
        );
      } else if (widget.mode == DishVersionMode.editExisting) {
        await dishService.updateDishVersion(
          versionId: widget.version.id,
          ingredients: _ingredients,
          directions: _directions,
          notes: _notesController.text,
          tags: _tags,
          photoPaths: [..._photoPaths, ...uploaded],
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      try {
        await _photoService.discardUploads(uploaded);
      } catch (cleanupError) {
        debugPrint('Could not clean up unsaved photos: $cleanupError');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save recipe: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.version.createdAt.toIso8601String().split('T').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.dish.name} • v${widget.version.versionNumber}',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          if (widget.mode == DishVersionMode.viewOnly) ...[
            IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => ExportService.sharePdf(
                dish: widget.dish,
                version: widget.version,
                isBest: widget.isBest,
              ),
            ),
            IconButton(
              tooltip: 'Export TXT',
              icon: const Icon(Icons.text_snippet),
              onPressed: () => ExportService.shareTxt(
                dish: widget.dish,
                version: widget.version,
                isBest: widget.isBest,
              ),
            ),
          ],
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader(
              context,
              title: 'Dish Info',
              trailing: widget.isBest
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.orange),
                        SizedBox(width: 6),
                        Text('Best'),
                      ],
                    )
                  : null,
            ),
            _readOnlyBox('Name', widget.dish.name),
            _readOnlyBox('Description', widget.dish.description),
            _readOnlyBox('Status', widget.version.status),
            _readOnlyBox('Created', dateStr),

            const SizedBox(height: 18),
            RecipePhotos(
              service: _photoService,
              paths: _photoPaths,
              pending: _photos,
              readOnly: _readOnly,
              onChanged: () {},
            ),

            const SizedBox(height: 18),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, title: "Ingredients"),
                  _buildReorderableList(_ingredients),
                ],
              ),
            ),

            const SizedBox(height: 18),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, title: "Directions"),
                  _buildReorderableList(_directions, numbered: true),
                ],
              ),
            ),

            const SizedBox(height: 18),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, title: "Tags"),
                  _buildTags(),
                ],
              ),
            ),

            const SizedBox(height: 18),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, title: "Notes"),
                  _buildNotes(),
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (!_readOnly)
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: Text(
                  _isSaving
                      ? 'Saving…'
                      : widget.mode == DishVersionMode.createNewVersion
                      ? "Create New Version"
                      : "Save Changes",
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------
  /// UI components to make it less ugly (not quite pretty yet)
  /// ------------------------------
  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _readOnlyBox(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(List<String> items, {bool numbered = false}) {
    if (_readOnly && items.isEmpty) {
      return _emptyHint("None");
    }

    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          buildDefaultDragHandles: false,
          onReorder: _readOnly
              ? (_, _) {}
              : (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                  });
                },
          proxyDecorator: (child, index, animation) {
            return Material(
              color: Colors.transparent,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // 🔥 your curved edges
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: child,
              ),
            );
          },
          itemBuilder: (context, index) {
            return Container(
              key: ValueKey('$index-${items[index]}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_readOnly)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6, top: 16),
                        child: Icon(Icons.drag_handle, size: 18),
                      ),
                    ),
                  if (numbered)
                    Padding(
                      padding: const EdgeInsets.only(top: 14, right: 6),
                      child: Text("${index + 1}."),
                    ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextFormField(
                        initialValue: items[index],
                        readOnly: _readOnly,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          items[index] = val;
                        },
                      ),
                    ),
                  ),
                  if (!_readOnly)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          items.removeAt(index);
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
        if (!_readOnly)
          TextButton.icon(
            onPressed: () {
              setState(() {
                items.add("");
              });
            },
            icon: const Icon(Icons.add),
            label: const Text("Add"),
          ),
      ],
    );
  }

  Widget _buildTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            return InputChip(
              label: Text(tag),
              onDeleted: _readOnly
                  ? null
                  : () {
                      setState(() {
                        _tags.remove(tag);
                      });
                    },
            );
          }).toList(),
        ),
        if (!_readOnly) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _tagController,
            decoration: const InputDecoration(
              hintText: "Add tag and press Enter",
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isEmpty) return;

              setState(() {
                _tags.add(trimmed);
                _tagController.clear();
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildNotes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: _notesController,
        readOnly: _readOnly,
        maxLines: null,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
