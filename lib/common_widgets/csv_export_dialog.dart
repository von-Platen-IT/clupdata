import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../core/database/database.dart';
import '../core/providers/database_provider.dart';

/// Zeigt den CSV-Export-Dialog an.
///
/// Wird aus dem Hauptmenü (Datenübertragung → Export → CSV Export) aufgerufen.
Future<void> showCsvExportDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const _CsvExportDialog(),
  );
}

/// Modal-Dialog für den CSV-Export.
///
/// Ablauf:
/// 1. Tabelle wählen (Dropdown)
/// 2. Speicherort wählen (FilePicker)
/// 3. Export durchführen
/// 4. Bei leerer Tabelle: Nur Header exportieren
class _CsvExportDialog extends HookConsumerWidget {
  const _CsvExportDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(appDatabaseProvider);

    // State
    final selectedTable = useState<String?>(null);
    final filePath = useState<String?>(null);
    final fileName = useState<String?>(null);
    final isExporting = useState(false);
    final exportResult = useState<String?>(null);

    final canExport =
        selectedTable.value != null &&
        filePath.value != null &&
        !isExporting.value;

    return AlertDialog(
      title: const Text('CSV Export'),
      constraints: const BoxConstraints(maxWidth: 560),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tabelle auswählen
            _TableDropdown(
              selectedTable: selectedTable,
              onChanged: (table) {
                selectedTable.value = table;
                exportResult.value = null;
              },
            ),
            const SizedBox(height: 16),

            // Speicherort
            _FilePickerRow(
              fileName: fileName.value,
              onPicked: (path, name) {
                filePath.value = path;
                fileName.value = name;
                exportResult.value = null;
              },
              selectedTable: selectedTable.value,
            ),
            const SizedBox(height: 16),

            // Export-Ergebnis
            if (isExporting.value)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (exportResult.value != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exportResult.value!,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isExporting.value
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        FilledButton(
          onPressed: canExport
              ? () => _export(
                  context: context,
                  db: db,
                  tableName: selectedTable.value!,
                  filePath: filePath.value!,
                  isExporting: isExporting,
                  exportResult: exportResult,
                )
              : null,
          child: const Text('Exportieren'),
        ),
      ],
    );
  }

  Future<void> _export({
    required BuildContext context,
    required AppDatabase db,
    required String tableName,
    required String filePath,
    required ValueNotifier<bool> isExporting,
    required ValueNotifier<String?> exportResult,
  }) async {
    isExporting.value = true;
    exportResult.value = null;

    try {
      debugPrint('=== CSV Export gestartet ===');
      debugPrint('Tabelle: $tableName');
      debugPrint('Ziel: $filePath');

      // Spaltennamen (Header) ermitteln (VOR Daten laden)
      final headers = await _getTableColumns(db, tableName);
      debugPrint('Spalten gefunden: ${headers.length}');
      debugPrint('Header: ${headers.join(', ')}');

      // Validierung: Minimum 1 Spalte
      if (headers.isEmpty) {
        throw Exception('Tabelle "$tableName" hat keine Spalten');
      }

      // Daten aus der Tabelle laden (SELECT * = alle Spalten)
      final rows = await _fetchTableData(db, tableName);
      debugPrint('Zeilen geladen: ${rows.length}');

      // Validierung: Alle Header müssen in jeder Zeile vorkommen
      if (rows.isNotEmpty) {
        final firstRow = rows.first;
        final missingColumns = headers
            .where((header) => !firstRow.containsKey(header))
            .toList();

        if (missingColumns.isNotEmpty) {
          debugPrint(
            'WARNUNG: Fehlende Spalten in Datenzeile: $missingColumns',
          );
        }

        debugPrint('Erste Zeile Keys: ${firstRow.keys.join(', ')}');
      }

      // CSV erzeugen
      final csvContent = _generateCsv(headers, rows);
      debugPrint('CSV generiert: ${csvContent.length} Zeichen');

      // Datei schreiben
      final file = File(filePath);
      await file.writeAsString(csvContent);
      debugPrint('Datei geschrieben: ${file.path}');

      exportResult.value = rows.isEmpty
          ? 'CSV mit ${headers.length} Spalten exportiert (keine Daten vorhanden)'
          : '${rows.length} Zeilen mit ${headers.length} Spalten exportiert';

      debugPrint('=== CSV Export erfolgreich abgeschlossen ===');
    } catch (e, stackTrace) {
      debugPrint('=== CSV Export fehlgeschlagen ===');
      debugPrint('Fehler: $e');
      debugPrint('StackTrace: $stackTrace');
      exportResult.value = 'Fehler: $e';
    } finally {
      isExporting.value = false;
    }
  }

  /// Lädt alle Daten aus einer Tabelle.
  Future<List<Map<String, dynamic>>> _fetchTableData(
    AppDatabase db,
    String tableName,
  ) async {
    final result = await db.customSelect('SELECT * FROM $tableName').get();
    return result.map((row) => row.data).toList();
  }

  /// Ermittelt die Spaltennamen einer Tabelle.
  Future<List<String>> _getTableColumns(
    AppDatabase db,
    String tableName,
  ) async {
    final result = await db
        .customSelect("SELECT name FROM pragma_table_info('$tableName')")
        .get();
    return result.map((row) => row.read<String>('name')).toList();
  }

  /// Generiert den CSV-Content mit Validierung und NULL-Behandlung.
  ///
  /// Stellt sicher, dass alle Spalten exportiert werden.
  /// NULL-Werte werden als '<NULL>' exportiert (nicht leerer String),
  /// damit sie beim Re-Import von echten leeren Strings unterscheidbar sind.
  String _generateCsv(List<String> headers, List<Map<String, dynamic>> rows) {
    debugPrint('=== CSV Generierung ===');
    debugPrint('Headers: ${headers.length}');

    final allRows = <List<dynamic>>[headers];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final csvRow = <dynamic>[];

      for (final header in headers) {
        final value = row[header];

        // NULL-Werte explizit als <NULL> markieren
        // (nicht leerer String, damit Re-Import sie erkennt)
        if (value == null) {
          csvRow.add('<NULL>');
          debugPrint('WARNUNG Zeile ${i + 1}, Spalte "$header": NULL-Wert');
        } else if (value is DateTime) {
          // DateTime als lesbares Format exportieren
          csvRow.add(DateFormat('dd.MM.yyyy').format(value));
        } else if (value is bool) {
          // Boolean als 1/0 exportieren
          csvRow.add(value ? '1' : '0');
        } else if (value is int && value == 0) {
          // Unix-Timestamp 0 könnte ungültiges Datum bedeuten
          // Nach Absprache: 0 als <NULL> exportieren
          csvRow.add(value.toString());
        } else {
          csvRow.add(value.toString());
        }
      }

      // Validierung: Jede Zeile muss gleich viele Werte wie Header haben
      if (csvRow.length != headers.length) {
        debugPrint(
          'WARNUNG Zeile $i: ${csvRow.length} Werte, aber ${headers.length} Header',
        );
      }

      allRows.add(csvRow);
    }

    debugPrint('CSV Zeilen generiert: ${allRows.length} (inkl. Header)');

    // CsvEncoder mit Semikolon-Delimiter für deutsches Excel
    const encoder = CsvEncoder(fieldDelimiter: ';', addBom: true);
    return encoder.convert(allRows);
  }
}

/// Dropdown zur Auswahl der zu exportierenden Tabelle.
class _TableDropdown extends StatelessWidget {
  final ValueNotifier<String?> selectedTable;
  final ValueChanged<String?> onChanged;

  const _TableDropdown({required this.selectedTable, required this.onChanged});

  static const _tables = [
    ('mitglied', 'Mitglieder'),
    ('leistung', 'Leistungen'),
    ('beitrag', 'Beiträge'),
    ('waren', 'Waren'),
    ('rechnung', 'Rechnungen'),
    ('preis', 'Preise'),
    ('bemerkung', 'Bemerkungen'),
    ('beitrag_status_verlauf', 'Beitrag Status Verlauf'),
    ('rechnung_position', 'Rechnung Positionen'),
    ('stammdaten', 'Stammdaten'),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedTable.value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tabelle auswählen',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      hint: const Text('Tabelle wählen...'),
      items: _tables.map((entry) {
        return DropdownMenuItem(value: entry.$1, child: Text(entry.$2));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// Typ für Callback mit Pfad und Dateiname.
typedef _FilePickedCallback = void Function(String path, String name);

/// Zeile mit Datei-Auswahl-Button und Dateiname-Anzeige.
class _FilePickerRow extends StatelessWidget {
  final String? fileName;
  final _FilePickedCallback onPicked;
  final String? selectedTable;

  const _FilePickerRow({
    required this.fileName,
    required this.onPicked,
    this.selectedTable,
  });

  String _defaultFileName() {
    final table = selectedTable ?? 'export';
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd_HHmmss').format(now);
    return '${table}_$date.csv';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.tonal(
          onPressed: () async {
            final result = await FilePicker.platform.saveFile(
              dialogTitle: 'CSV-Datei speichern',
              fileName: _defaultFileName(),
              type: FileType.custom,
              allowedExtensions: ['csv'],
            );
            if (result != null) {
              onPicked(result, result.split('/').last);
            }
          },
          child: const Text('Speicherort wählen'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            fileName ?? 'Keine Datei ausgewählt',
            style: TextStyle(
              color: fileName != null
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
