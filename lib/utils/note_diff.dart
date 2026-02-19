import 'package:flutter/material.dart';

enum DiffOp { equal, insert, delete }

class DiffChunk {
  final DiffOp op;
  final String text;
  DiffChunk(this.op, this.text);
}

List<String> _tokenizePreserveSpaces(String s) {
  final re = RegExp(r'\s+|[^\s]+');
  return re.allMatches(s).map((m) => m.group(0)!).toList();
}

List<DiffChunk> diffText(String oldText, String newText) {
  final a = _tokenizePreserveSpaces(oldText);
  final b = _tokenizePreserveSpaces(newText);

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
    if (chunks.isNotEmpty && chunks.last.op == op) {
      chunks[chunks.length - 1] = DiffChunk(op, chunks.last.text + text);
    } else {
      chunks.add(DiffChunk(op, text));
    }
  }

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
      push(DiffOp.equal, a[i - 1]);
      i--; j--;
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

TextSpan buildDiffSpan({
  required String oldText,
  required String newText,
  required BuildContext context,
  bool showDeletions = true,
}) {
  final cs = Theme.of(context).colorScheme;
  final baseStyle = DefaultTextStyle.of(context).style;

  final chunks = diffText(oldText, newText);

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
              backgroundColor: cs.primary.withValues(alpha:0.20),
              fontWeight: FontWeight.w600,
            ),
          );

        case DiffOp.delete:
          if (!showDeletions) return const TextSpan(text: "");
          return TextSpan(
            text: c.text,
            style: baseStyle.copyWith(
              color: cs.error.withValues(alpha:0.85),
              decoration: TextDecoration.lineThrough,
              decorationThickness: 2,
            ),
          );
      }
    }).toList(),
  );
}
