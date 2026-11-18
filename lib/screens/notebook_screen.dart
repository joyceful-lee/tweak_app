import 'package:flutter/material.dart';
import '../auth.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import 'note_editor_screen.dart';

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final NoteService _noteService = NoteService(backend);
  List<Note> _notes = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String? _selectedTag;
  bool _sortByAlpha = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(() {
      if (mounted) {
        setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase(),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await _noteService.fetchNotes();
      setState(() => _notes = notes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading notes: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Note> get _visibleNotes {
    var list = _notes;

    // 1. Tag Filter
    if (_selectedTag != null) {
      list = list.where((n) => n.tags.contains(_selectedTag)).toList();
    }

    // 2. Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((n) {
        final titleMatch = n.title.toLowerCase().contains(_searchQuery);
        final contentMatch = n.content.toLowerCase().contains(_searchQuery);
        final tagMatch = n.tags.any(
          (t) => t.toLowerCase().contains(_searchQuery),
        );
        return titleMatch || contentMatch || tagMatch;
      }).toList();
    }

    // 3. Sorting
    if (_sortByAlpha) {
      list.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return list;
  }

  Widget _buildSearchBar(ColorScheme cs) {
    final allTags = _notes.expand((n) => n.tags).toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search notes or tags...",
                prefixIcon: Icon(Icons.search, color: cs.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: cs.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
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
                  _sortByAlpha
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 20,
                  color: cs.primary,
                ),
                child: const Text("Sort A-Z"),
              ),
              const PopupMenuDivider(),
              if (allTags.isEmpty)
                const MenuItemButton(
                  onPressed: null,
                  child: Text("No tags found"),
                )
              else ...[
                MenuItemButton(
                  onPressed: _selectedTag == null
                      ? null
                      : () => setState(() => _selectedTag = null),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final notes = _visibleNotes;

    return Scaffold(
      backgroundColor: cs.onTertiaryFixedVariant,
      appBar: AppBar(title: const Text("Notebook")),
      body: Column(
        children: [
          _buildSearchBar(cs),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty && _selectedTag == null
                          ? "No notes yet. Tap + to create one."
                          : "No matching notes found.",
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            note.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (note.tags.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 4,
                                    children: note.tags
                                        .map(
                                          (t) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              t,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: cs.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Delete note?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _noteService.deleteNote(note.id);
                                _loadNotes();
                              }
                            },
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NoteEditorScreen(note: note),
                              ),
                            );
                            _loadNotes();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
          );
          _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
