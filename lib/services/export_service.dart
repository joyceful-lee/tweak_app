import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dish.dart';
import '../services/dish_service.dart';
import '../services/note_service.dart';

class ExportService {
  /// ------------------------------
  /// Replace characters that cause issues on iOS/Android/Windows filesystems.
  /// ------------------------------
  static String _safeFilename(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'recipe' : cleaned;
  }

  /// ------------------------------
  /// Create TXT File
  /// ------------------------------
  static String buildRecipeTxt({
    required Dish dish,
    required DishVersion version,
    required bool isBest,
  }) {
    final dateStr = version.createdAt.toIso8601String().split('T').first;

    final ingredients = version.ingredients
        .where((s) => s.trim().isNotEmpty)
        .map((s) => '• $s')
        .join('\n');

    final directions = version.directions
        .where((s) => s.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    final tags = version.tags
        .where((t) => t.trim().isNotEmpty)
        .map((t) => '- $t')
        .join('\n');

    final notes = version.notes.trim();

    return '''
      Dish: ${dish.name}
      Version: ${version.versionNumber}${isBest ? " (Best)" : ""}
      Status: ${version.status}
      Created: $dateStr
      
      INGREDIENTS
      ${ingredients.isEmpty ? "(none)" : ingredients}
      
      DIRECTIONS
      ${directions.isEmpty ? "(none)" : directions}
      
      TAGS
      ${tags.isEmpty ? "(none)" : tags}
      
      NOTES
      ${notes.isEmpty ? "(none)" : notes}
      '''
        .trim();
  }

  /// ------------------------------
  /// Share TXT
  /// ------------------------------
  static Future<void> shareTxt({
    required Dish dish,
    required DishVersion version,
    required bool isBest,
  }) async {
    final txt = buildRecipeTxt(dish: dish, version: version, isBest: isBest);

    final fileName = _safeFilename(
      '${dish.name}_v${version.versionNumber}.txt',
    );

    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode(txt)),
        mimeType: 'text/plain',
        name: fileName,
      ),
    ], text: '${dish.name} • v${version.versionNumber}');
  }

  /// ------------------------------
  /// Share PDF
  /// ------------------------------
  static Future<void> sharePdf({
    required Dish dish,
    required DishVersion version,
    required bool isBest,
  }) async {
    final doc = pw.Document();
    final dateStr = version.createdAt.toIso8601String().split('T').first;

    pw.Widget sectionTitle(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        t,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
    );

    pw.Widget keyValue(String k, String v) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              '$k:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(v)),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          final ingredients = version.ingredients
              .where((s) => s.trim().isNotEmpty)
              .toList();
          final directions = version.directions
              .where((s) => s.trim().isNotEmpty)
              .toList();
          final tags = version.tags.where((t) => t.trim().isNotEmpty).toList();
          final notes = version.notes.trim();

          return [
            pw.Text(
              '${dish.name} • v${version.versionNumber}${isBest ? " (Best)" : ""}',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            keyValue('Status', version.status),
            keyValue('Created', dateStr),

            sectionTitle('Ingredients'),
            if (ingredients.isEmpty)
              pw.Text('(none)')
            else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: ingredients.map((s) => pw.Bullet(text: s)).toList(),
              ),

            sectionTitle('Directions'),
            if (directions.isEmpty)
              pw.Text('(none)')
            else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: directions
                    .asMap()
                    .entries
                    .map(
                      (e) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text('${e.key + 1}. ${e.value}'),
                      ),
                    )
                    .toList(),
              ),

            sectionTitle('Tags'),
            pw.Text(tags.isEmpty ? '(none)' : tags.join(', ')),

            sectionTitle('Notes'),
            pw.Text(notes.isEmpty ? '(none)' : notes),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    final fileName = _safeFilename(
      '${dish.name}_v${version.versionNumber}.pdf',
    );

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  /// ------------------------------
  /// Bulk Export All Data (JSON)
  /// ------------------------------
  static Future<void> exportAllData({
    required DishService dishService,
    required NoteService noteService,
  }) async {
    final dishes = await dishService.fetchAllDishesFull();
    final notes = await noteService.fetchNotes();

    final exportData = {
      'exported_at': DateTime.now().toIso8601String(),
      'recipes': dishes.map((d) => d.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    final fileName =
        'tweak_export_${DateTime.now().millisecondsSinceEpoch}.json';

    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode(jsonString)),
        mimeType: 'application/json',
        name: fileName,
      ),
    ], text: 'My Tweak Data Export');
  }
}
