import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/recipe_photo_service.dart';

/// Pending bytes stay in the form until Save; cancelling never uploads files.
class RecipePhotos extends StatefulWidget {
  final RecipePhotoService service;
  final List<String> paths;
  final List<Uint8List> pending;
  final bool readOnly;
  final VoidCallback onChanged;

  const RecipePhotos({
    super.key,
    required this.service,
    required this.paths,
    required this.pending,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<RecipePhotos> createState() => _RecipePhotosState();
}

class _RecipePhotosState extends State<RecipePhotos> {
  final _picker = ImagePicker();
  bool _picking = false;
  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _pick(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await RecipePhotoService.readPhoto(file);
      if (!mounted) return;
      setState(() => widget.pending.add(bytes));
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.paths.length + widget.pending.length;
    final canAdd = !_picking && count < RecipePhotoService.maxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recipe photos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (count == 0) const Text('No photos yet.'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final path in widget.paths)
              _tile(
                StoredRecipePhoto(
                  key: ValueKey(path),
                  service: widget.service,
                  path: path,
                ),
                () {
                  setState(() => widget.paths.remove(path));
                  widget.onChanged();
                },
              ),
            for (var i = 0; i < widget.pending.length; i++)
              _tile(Image.memory(widget.pending[i], fit: BoxFit.cover), () {
                setState(() => widget.pending.removeAt(i));
                widget.onChanged();
              }),
          ],
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canAdd ? () => _pick(ImageSource.gallery) : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Upload photo'),
              ),
              if (_cameraSupported)
                OutlinedButton.icon(
                  onPressed: canAdd ? () => _pick(ImageSource.camera) : null,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Take photo'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _picking
                ? 'Opening photo…'
                : '$count/${RecipePhotoService.maxPhotos} photos · JPEG, PNG or WebP · up to 4 MB each',
          ),
        ],
      ],
    );
  }

  Widget _tile(Widget image, VoidCallback remove) => SizedBox(
    width: 160,
    height: 160,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
        if (!widget.readOnly)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filled(
              tooltip: 'Remove photo',
              onPressed: remove,
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    ),
  );
}

class StoredRecipePhoto extends StatefulWidget {
  final RecipePhotoService service;
  final String path;
  const StoredRecipePhoto({
    super.key,
    required this.service,
    required this.path,
  });

  @override
  State<StoredRecipePhoto> createState() => _StoredRecipePhotoState();
}

class _StoredRecipePhotoState extends State<StoredRecipePhoto> {
  late Future<String> _url;
  @override
  void initState() {
    super.initState();
    _url = widget.service.signedUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _retry();
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return Image.network(
        snapshot.data!,
        headers: widget.service.imageHeaders,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _retry(),
      );
    },
  );

  Widget _retry() => Center(
    child: TextButton.icon(
      onPressed: () =>
          setState(() => _url = widget.service.signedUrl(widget.path)),
      icon: const Icon(Icons.refresh),
      label: const Text('Reload photo'),
    ),
  );
}
