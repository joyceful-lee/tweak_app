import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/dish_service.dart';

class DishAllNotesScreen extends StatefulWidget {
  final Dish dish;
  final DishService dishService;

  const DishAllNotesScreen({
    super.key,
    required this.dish,
    required this.dishService,
  });

  @override
  State<DishAllNotesScreen> createState() => _DishAllNotesScreenState();
}

class _DishAllNotesScreenState extends State<DishAllNotesScreen> {
  bool _isLoading = true;
  List<DishVersion> _versions = []; // keep ALL for correct baselines

  bool _showChanges = true;
  final bool _highlightDiff = true;
  bool _showDeletions = true;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      final versions = await widget.dishService.fetchDishVersions(widget.dish.id);
      versions.sort((a, b) => b.versionNumber.compareTo(a.versionNumber)); // newest first
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

  String _statusText(DishVersion v) => v.status.trim();

  String _tagsText(DishVersion v) {
    if (v.tags.isEmpty) return "";
    return v.tags.join(", ").trim();
  }

  bool _isDifferent(String a, String b) => a.trim() != b.trim();

  Widget _buildTextFieldDiff({
    required String title,
    required String olderValue,
    required String currentValue,
  }) {
    if (currentValue.trim().isEmpty && olderValue.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_highlightDiff && !_isDifferent(olderValue, currentValue)) {
      return const SizedBox.shrink();
    }

    final Widget body = !_highlightDiff
        ? Text(currentValue, style: const TextStyle(height: 1.35))
        : RichText(
      text: buildDiffSpanWords(
        oldText: olderValue,
        newText: currentValue,
        context: context,
        showDeletions: _showDeletions,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }

  Widget _buildListFieldDiff({
    required String title,
    required List<String> olderItems,
    required List<String> currentItems,
    required String Function(int index, String item) prefixBuilder, // bullet/number
  }) {
    final olderClean = olderItems.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final currentClean = currentItems.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (olderClean.isEmpty && currentClean.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_highlightDiff && _listsEqual(olderClean, currentClean)) {
      return const SizedBox.shrink();
    }

    if (!_highlightDiff) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...List.generate(currentClean.length, (i) {
              final item = currentClean[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "${prefixBuilder(i, item)}$item",
                  style: const TextStyle(height: 1.35),
                ),
              );
            }),
          ],
        ),
      );
    }

    final chunks = diffListItems(olderClean, currentClean);

    final hasChange = chunks.any((c) => c.op != DiffOp.equal);
    if (!hasChange) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    int currentIndexForPrefix = 0;

    final lines = <Widget>[];
    for (final c in chunks) {
      if (c.op == DiffOp.equal) {
        currentIndexForPrefix++;
        continue;
      }

      if (c.op == DiffOp.insert) {
        final prefix = prefixBuilder(currentIndexForPrefix, c.text);
        lines.add(_lineRich(
          text: "$prefix${c.text}",
          style: TextStyle(
            color: cs.secondary,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ));
        currentIndexForPrefix++;
        continue;
      }

      if (c.op == DiffOp.delete) {
        if (!_showDeletions) continue;

        lines.add(_lineRich(
          text: "× ${c.text}",
          style: TextStyle(
            color: cs.error,
            decoration: TextDecoration.lineThrough,
            decorationColor: cs.error.withValues(alpha: .8),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
          ),
        ));
        continue;
      }
    }

    if (lines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...lines,
        ],
      ),
    );
  }

  Widget _lineRich({required String text, required TextStyle style}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: style),
    );
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final indicesWithNotes = <int>[];
    for (var i = 0; i < _versions.length; i++) {
      if (_versions[i].notes.trim().isNotEmpty) indicesWithNotes.add(i);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.dish.name} • Notes",
          style: TextStyle(fontSize: 14),
        ),
        backgroundColor: cs.onSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadVersions,
        child: indicesWithNotes.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text("No notes found in any version.")),
          ],
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Show changes"),
                      value: _showChanges,
                      onChanged: (v) => setState(() => _showChanges = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Show removed items"),
                      subtitle: const Text("Removed items show as strikethrough"),
                      value: _showDeletions,
                      onChanged: _showChanges ? (v) => setState(() => _showDeletions = v) : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...indicesWithNotes.map((i) {
              final current = _versions[i];
              final older = (i + 1 < _versions.length) ? _versions[i + 1] : null;

              final isVersionOne = older == null || current.versionNumber == 1;
              final dateStr = current.createdAt.toIso8601String().split('T').first;

              final notesText = current.notes.trim();

              // TEXT fields
              final curStatus = _statusText(current);
              final curTags = _tagsText(current);
              final oldStatus = older == null ? "" : _statusText(older);
              final oldTags = older == null ? "" : _tagsText(older);

              // LIST fields (diff by list item)
              final curIngredients = current.ingredients;
              final oldIngredients = older == null ? const <String>[] : older.ingredients;

              final curDirections = current.directions;
              final oldDirections = older == null ? const <String>[] : older.directions;

              Widget changesSection = const SizedBox.shrink();
              if (_showChanges && !isVersionOne) {
                final fields = <Widget>[
                  _buildTextFieldDiff(
                    title: "Status",
                    olderValue: oldStatus,
                    currentValue: curStatus,
                  ),
                  _buildTextFieldDiff(
                    title: "Tags",
                    olderValue: oldTags,
                    currentValue: curTags,
                  ),
                  _buildListFieldDiff(
                    title: "Ingredients",
                    olderItems: oldIngredients,
                    currentItems: curIngredients,
                    prefixBuilder: (_, _) => "• ",
                  ),
                  _buildListFieldDiff(
                    title: "Directions",
                    olderItems: oldDirections,
                    currentItems: curDirections,
                    prefixBuilder: (idx, _) => "${idx + 1}. ",
                  ),
                ].where((w) => w is! SizedBox).toList();

                final hasAnyField = fields.isNotEmpty;
                if (!_highlightDiff || hasAnyField) {
                  changesSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Changes",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...fields,
                      const SizedBox(height: 2),
                    ],
                  );
                }
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Version ${current.versionNumber}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      changesSection,
                      const Text(
                        "Notes",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(notesText, style: const TextStyle(height: 1.35)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

enum DiffOp { equal, insert, delete }

class DiffChunk {
  final DiffOp op;
  final String text;
  DiffChunk(this.op, this.text);
}

List<String> _tokenizeWordsPreserveSpaces(String s) {
  final re = RegExp(r'\s+|[^\s]+');
  return re.allMatches(s).map((m) => m.group(0)!).toList();
}

List<DiffChunk> _diffTokens(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  var i = n, j = m;
  final chunks = <DiffChunk>[];

  void push(DiffOp op, String text) {
    if (text.isEmpty) return;
    if (chunks.isNotEmpty && chunks.last.op == op) {
      chunks[chunks.length - 1] = DiffChunk(op, chunks.last.text + text);
    } else {
      chunks.add(DiffChunk(op, text));
    }
  }

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
      push(DiffOp.equal, a[i - 1]);
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      push(DiffOp.insert, b[j - 1]);
      j--;
    } else if (i > 0) {
      push(DiffOp.delete, a[i - 1]);
      i--;
    }
  }

  return chunks.reversed.toList();
}

TextSpan buildDiffSpanWords({
  required String oldText,
  required String newText,
  required BuildContext context,
  bool showDeletions = true,
}) {
  final a = _tokenizeWordsPreserveSpaces(oldText);
  final b = _tokenizeWordsPreserveSpaces(newText);
  final chunks = _diffTokens(a, b);

  final cs = Theme.of(context).colorScheme;
  final baseStyle = DefaultTextStyle.of(context).style.copyWith(height: 1.35);

  return TextSpan(
    style: baseStyle,
    children: chunks.map((c) {
      switch (c.op) {
        case DiffOp.equal:
          return TextSpan(text: c.text);
        case DiffOp.insert:
          return TextSpan(
            text: c.text,
            style: baseStyle.copyWith(
              fontSize: 12,
              color: cs.primary,
            ),
          );
        case DiffOp.delete:
          if (!showDeletions) return const TextSpan(text: "");
          return TextSpan(
            text: c.text,
            style: baseStyle.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: .5),
            ),
          );
      }
    }).toList(),
  );
}

List<DiffChunk> diffListItems(List<String> oldItems, List<String> newItems) {
  // LCS on items
  final n = oldItems.length, m = newItems.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      if (oldItems[i - 1] == newItems[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  var i = n, j = m;
  final chunks = <DiffChunk>[];

  void push(DiffOp op, String text) {
    if (chunks.isNotEmpty && chunks.last.op == op && chunks.last.text == text) {
      return;
    }
    chunks.add(DiffChunk(op, text));
  }

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldItems[i - 1] == newItems[j - 1]) {
      push(DiffOp.equal, oldItems[i - 1]);
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      push(DiffOp.insert, newItems[j - 1]);
      j--;
    } else if (i > 0) {
      push(DiffOp.delete, oldItems[i - 1]);
      i--;
    }
  }

  return chunks.reversed.toList();
}
