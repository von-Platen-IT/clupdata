import 'dart:io';
import 'dart:typed_data';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../widgets/data_grid/sort_column_config.dart';

/// Einfacher PrintService ohne Freezed-Modelle für die Listen-Druckfunktionalität
class SimplePrintService {
  /// Zeigt einen Dialog mit Druckoptionen an
  static Future<void> showPrintOptionsDialog({
    required BuildContext context,
    required List<PlutoRow> rows,
    required List<PlutoColumn> columns,
    required String listTitle,
    required String listType,
    Map<String, String> activeFilters = const {},
    List<SortColumnConfig> activeSortConfigs = const [],
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$listTitle drucken'),
        content: Text(
          'Möchten Sie die aktuelle Liste drucken, speichern oder teilen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Abbrechen'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop('print'),
            icon: const Icon(Icons.print),
            label: const Text('Drucken'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop('save'),
            icon: const Icon(Icons.save),
            label: const Text('Speichern'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop('share'),
            icon: const Icon(Icons.share),
            label: const Text('Teilen'),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return;

    try {
      final pdfData = await generateSimpleListPdf(
        rows: rows,
        columns: columns,
        listTitle: listTitle,
        listType: listType,
        activeFilters: activeFilters,
        activeSortConfigs: activeSortConfigs,
      );

      switch (result) {
        case 'print':
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfData,
            name:
                '${listType}_${DateTime.now().toIso8601String().split('T').first}.pdf',
          );
          break;
        case 'save':
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now()
              .toIso8601String()
              .replaceAll(':', '-')
              .replaceAll('.', '-');
          final file = File('${directory.path}/${listType}_$timestamp.pdf');
          await file.writeAsBytes(pdfData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF gespeichert: ${file.path}')),
          );
          break;
        case 'share':
          await Printing.sharePdf(
            bytes: pdfData,
            filename:
                '${listType}_${DateTime.now().toIso8601String().split('T').first}.pdf',
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Erstellen des PDFs: $e')),
      );
    }
  }

  /// Generiert ein einfaches PDF für eine Liste
  static Future<Uint8List> generateSimpleListPdf({
    required List<PlutoRow> rows,
    required List<PlutoColumn> columns,
    required String listTitle,
    required String listType,
    Map<String, String> activeFilters = const {},
    List<SortColumnConfig> activeSortConfigs = const [],
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                listTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Erstellt am: ${_formatDateTime(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Tabelle mit den Daten
              _buildSimpleTable(rows, columns),

              pw.SizedBox(height: 20),
              pw.Text(
                'Gesamt: ${rows.length} Einträge',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Baut eine einfache Tabelle für die Daten
  static pw.Widget _buildSimpleTable(
    List<PlutoRow> rows,
    List<PlutoColumn> columns,
  ) {
    final visibleColumns = columns.where((col) => !col.hide).toList();

    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      headers: visibleColumns.map((col) => col.title).toList(),
      data: rows.map((row) {
        return visibleColumns.map((col) {
          final cellValue = row.cells[col.field]?.value;
          return cellValue?.toString() ?? '';
        }).toList();
      }).toList(),
    );
  }

  /// Formatiert Datum und Zeit
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Provider für den einfachen PrintService
final simplePrintServiceProvider = Provider<SimplePrintService>((ref) {
  return SimplePrintService();
});
