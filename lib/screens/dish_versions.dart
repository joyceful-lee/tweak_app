import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/dish_service.dart';
import 'edit_dish_version.dart';

/// ------------------------------
/// Screen that lists the various versions of a dish
/// ------------------------------
class DishVersionsScreen extends StatefulWidget {
  final Dish dish;
  final DishService dishService;

  const DishVersionsScreen({
    super.key,
    required this.dish,
    required this.dishService,
  });

  @override
  State<DishVersionsScreen> createState() => _DishVersionsScreenState();
}

class _DishVersionsScreenState extends State<DishVersionsScreen> {
  List<DishVersion> _versions = [];
  bool _isLoading = true;
  String? _bestVersionId;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.dish.status;
    _loadVersions();
  }

  /// ------------------------------
  /// Load all the versions -> the best one so far is highlighted and starred
  /// ------------------------------
  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      final dishMap = await widget.dishService.fetchDishById(widget.dish.id);
      _bestVersionId = dishMap['best_version']?.toString();

      // Keep local status in sync with DB in case it changed elsewhere
      final dbStatus = dishMap['status']?.toString();
      if (dbStatus != null) {
        _currentStatus = dbStatus;
      }

      final versions =
      await widget.dishService.fetchDishVersions(widget.dish.id);
      setState(() => _versions = versions);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load versions: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ------------------------------
  /// On Tap -> choose what to do with version
  /// 1. Make Best
  /// 2. Increment (new version will appear)
  /// 3. Edit (edit current version)
  /// 4. View and Export
  /// 5. Delete this Version (version numbers won't change)
  /// ------------------------------
  void _onVersionTap(DishVersion version) {
    final isBest = version.id == _bestVersionId;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (!isBest)
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Star this version (make best)'),
                onTap: () async {
                  Navigator.pop(context);
                  await widget.dishService
                      .updateBestVersion(widget.dish.id, version.id);
                  await _loadVersions();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Best version updated")),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Increment version from this'),
              onTap: () {
                final isBestLocal = version.id == _bestVersionId;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditDishVersion(
                      dish: widget.dish,
                      version: version,
                      mode: DishVersionMode.createNewVersion,
                      isBest: isBestLocal,
                    ),
                  ),
                ).then((_) => _loadVersions());
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit this version'),
              onTap: () {
                final isBestLocal = version.id == _bestVersionId;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditDishVersion(
                      dish: widget.dish,
                      version: version,
                      mode: DishVersionMode.editExisting,
                      isBest: isBestLocal,
                    ),
                  ),
                ).then((_) => _loadVersions());
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View / Export this version'),
              onTap: () {
                final isBestLocal = version.id == _bestVersionId;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditDishVersion(
                      dish: widget.dish,
                      version: version,
                      mode: DishVersionMode.viewOnly,
                      isBest: isBestLocal,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete this version'),
              onTap: () async {
                Navigator.pop(context);
                await widget.dishService.deleteVersion(widget.dish.id, version.id);
                await _loadVersions();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Deleted version")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------
  /// Toggle dish status
  /// ------------------------------
  Widget _buildStatusToggle() {
    final cs = Theme.of(context).colorScheme;
    Color statusColor(String status) {
      switch (status) {
        case 'finalized':
          return cs.secondary;
        case 'abandoned':
          return cs.error;
        default:
          return cs.primary; // in_testing
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Dish Status",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'finalized',
                label: Text('Finalized'),
                icon: Icon(Icons.check_circle)
              ),
              ButtonSegment(
                value: 'in_testing',
                label: Text('In Testing'),
                icon: Icon(Icons.science),
              ),
              ButtonSegment(
                value: 'abandoned',
                label: Text('Abandoned'),
                icon: Icon(Icons.cancel),
              ),
            ],
            selected: {_currentStatus},
            onSelectionChanged: (newSelection) async {
              final newStatus = newSelection.first;

              // Optional confirmation for abandoning
              if (newStatus == 'abandoned' &&
                  _currentStatus != 'abandoned') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Mark as abandoned?"),
                    content: const Text(
                        "You can still change it later."),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(ctx, true),
                        child: const Text("Abandon"),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;
              }

              setState(() {
                _currentStatus = newStatus;
              });

              await widget.dishService.updateDishStatus(
                dishId: widget.dish.id,
                status: newStatus,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Status updated to ${newStatus.replaceAll('_', ' ')}",
                  ),
                ),
              );
            },
            style: ButtonStyle(
              backgroundColor:
              WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return statusColor(_currentStatus).withValues(alpha:0.15);
                }
                return Colors.grey.shade100;
              }),
              foregroundColor:
              WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return statusColor(_currentStatus);
                }
                return Colors.grey.shade700;
              }),
              side: WidgetStateProperty.all(
                BorderSide(
                  color: statusColor(_currentStatus),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dish.name),
        backgroundColor: cs.onSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildStatusToggle(),
          const SizedBox(height: 6),
          Expanded(
            child: _versions.isEmpty
                ? const Center(child: Text("No versions yet."))
                : RefreshIndicator(
              onRefresh: _loadVersions,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: _versions.length,
                itemBuilder: (context, index) {
                  final v = _versions[index];
                  final isBest = v.id == _bestVersionId;
                  final cs = Theme.of(context).colorScheme;

                  return Card(
                    color: isBest ? cs.secondary.withValues(alpha:0.2) : null,
                    child: ListTile(
                      title: Row(
                        children: [
                          Text(
                            "Version ${v.versionNumber}",
                            style: TextStyle(
                              color: isBest
                                  ? cs.onSurface
                                  : cs.onSurface,
                            ),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.star,
                                color: Colors.orange),
                          ]
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Date: ${v.createdAt.toIso8601String().split('T').first}",
                          ),
                        ],
                      ),
                      onTap: () => _onVersionTap(v),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
