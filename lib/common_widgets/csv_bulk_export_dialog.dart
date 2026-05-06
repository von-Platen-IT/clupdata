import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/data/csv_export_service.dart';
import '../core/providers/database_provider.dart';

/// Zeigt den CSV Bulk-Export-Dialog an.
///
/// Ermöglicht den Export einer oder mehrerer Tabellen als CSV-Dateien
/// in einen ausgewählten Ordner.
Future<void> showCsvBulkExportDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const _CsvBulkExportDialog(),
  );
}

/// Bekannte Tabellen für den Export.
const _exportableTables = [
  ('bemerkung', 'Bemerkungen'),
  ('stammdaten', 'Stammdaten'),
  ('preis', 'Preise'),
  ('leistung', 'Leistungen'),
  ('mitglied', 'Mitglieder'),
  ('waren', 'Waren'),
  ('beitrag', 'Beiträge'),
  ('beitrag_status_verlauf', 'Beitragsstatus-Verlauf'),
  ('rechnung', 'Rechnungen'),
  ('rechnung_position', 'Rechnungspositionen'),
];

/// CSV Bulk-Export Dialog.
///
/// Features:
/// - Ordner-Auswahl als Ziel
/// - Checkboxen für jede Tabelle
/// - "Alle auswählen / Alle abwählen"
/// - Zeigt Datensatz-Anzahl pro Tabelle
/// - Progress-Anzeige pro Tabelle
class _CsvBulkExportDialog extends HookConsumerWidget {
  const _CsvBulkExportDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(appDatabaseProvider);

    // State
    final selectedDir = useState<String?>(null);
    final selectedTables = useState<Set<String>>({});
    final rowCounts = useState<Map<String, int>>({});
    final isLoadingRowCounts = useState(false);

    // Export State
    final isExporting = useState(false);
    final exportProgress = useState(0.0);
    final currentExportTable = useState<String>('');
    final currentExportIndex = useState(0);
    final totalExportTables = useState(0);
    final exportResult = useState<BulkExportResult?>(null);

    // Cancel token
    final cancelToken = useState<bool>(false);

    useEffect(() {
      return () {
        cancelToken.value = true;
      };
    }, []);

    // -----------------------------------------------------------------------
    // Zeilenanzahl laden
    // -----------------------------------------------------------------------
    Future<void> loadRowCounts() async {
      isLoadingRowCounts.value = true;
      final counts = <String, int>{};

      for (final entry in _exportableTables) {
        try {
          final result = await db
              .customSelect('SELECT COUNT(*) as cnt FROM ${entry.$1}')
              .getSingle();
          counts[entry.$1] = result.read<int>('cnt');
        } catch (_) {
          counts[entry.$1] = 0;
        }
      }

      rowCounts.value = counts;
      isLoadingRowCounts.value = false;
    }

    // -----------------------------------------------------------------------
    // Ordner auswählen
    // -----------------------------------------------------------------------
    Future<void> pickDirectory() async {
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Zielordner für CSV-Export auswählen',
      );

      if (dir == null) return;

      selectedDir.value = dir;
      // Zeilenanzahl laden sobald Ordner gewählt
      await loadRowCounts();
    }

    // -----------------------------------------------------------------------
    // Auswahl-Helfer
    // -----------------------------------------------------------------------
    void selectAll() {
      selectedTables.value = _exportableTables.map((e) => e.$1).toSet();
    }

    void deselectAll() {
      selectedTables.value = {};
    }

    void toggleTable(String tableName) {
      final current = Set<String>.from(selectedTables.value);
      if (current.contains(tableName)) {
        current.remove(tableName);
      } else {
        current.add(tableName);
      }
      selectedTables.value = current;
    }

    // -----------------------------------------------------------------------
    // Export starten
    // -----------------------------------------------------------------------
    Future<void> startExport() async {
      if (selectedDir.value == null || selectedTables.value.isEmpty) return;

      isExporting.value = true;
      exportProgress.value = 0.0;
      exportResult.value = null;
      cancelToken.value = false;
      totalExportTables.value = selectedTables.value.length;

      try {
        final result = await CsvExportService.exportMultipleTables(
          db,
          selectedTables.value.toList(),
          selectedDir.value!,
          onProgress:
              ({
                required String currentTable,
                required int tableIndex,
                required int totalTables,
                required double tableProgress,
                required int tableExportedRows,
                required int tableTotalRows,
              }) {
                if (!cancelToken.value) {
                  currentExportTable.value = currentTable;
                  currentExportIndex.value = tableIndex;
                  final overallProgress =
                      (tableIndex + tableProgress) / totalTables;
                  exportProgress.value = overallProgress;
                }
              },
        );

        exportResult.value = result;
      } catch (e) {
        if (!cancelToken.value && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $e')));
        }
      } finally {
        isExporting.value = false;
      }
    }

    // -----------------------------------------------------------------------
    // Cancel
    // -----------------------------------------------------------------------
    void cancelExport() {
      cancelToken.value = true;
      isExporting.value = false;
    }

    // -----------------------------------------------------------------------
    // UI
    // -----------------------------------------------------------------------
    final hasSelection = selectedTables.value.isNotEmpty;
    final hasDirectory = selectedDir.value != null;

    return AlertDialog(
      title: const Text('CSV Export'),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ordner-Auswahl
              _DirectoryPickerSection(
                selectedDir: selectedDir.value,
                onPickDirectory: pickDirectory,
              ),

              const SizedBox(height: 16),

              // Tabellen-Auswahl (nur wenn Ordner gewählt)
              if (hasDirectory) ...[
                Row(
                  children: [
                    Text(
                      'Zu exportierende Tabellen:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: selectAll,
                      child: const Text('Alle auswählen'),
                    ),
                    TextButton(
                      onPressed: deselectAll,
                      child: const Text('Alle abwählen'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (isLoadingRowCounts.value)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: _exportableTables.map((entry) {
                          final tableName = entry.$1;
                          final displayName = entry.$2;
                          final count = rowCounts.value[tableName] ?? 0;
                          final isSelected = selectedTables.value.contains(
                            tableName,
                          );

                          return CheckboxListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              displayName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            subtitle: Text(
                              '$count Datensätze',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            value: isSelected,
                            onChanged: (_) => toggleTable(tableName),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 16),

              // Progress
              if (isExporting.value) ...[
                _ExportProgressHeader(
                  currentTable: currentExportTable.value,
                  tableIndex: currentExportIndex.value,
                  totalTables: totalExportTables.value,
                ),
                const SizedBox(height: 8),
                _ExportProgressSection(
                  progress: exportProgress.value,
                  onCancel: cancelExport,
                ),
              ],

              // Ergebnis
              if (exportResult.value != null) ...[
                const SizedBox(height: 8),
                _ExportResultCard(result: exportResult.value!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isExporting.value
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        if (isExporting.value)
          TextButton(onPressed: cancelExport, child: const Text('Abbrechen')),
        if (!isExporting.value && exportResult.value == null)
          FilledButton(
            onPressed: hasDirectory && hasSelection ? startExport : null,
            child: const Text('Export starten'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-Widgets
// ---------------------------------------------------------------------------

class _DirectoryPickerSection extends StatelessWidget {
  final String? selectedDir;
  final VoidCallback onPickDirectory;

  const _DirectoryPickerSection({
    required this.selectedDir,
    required this.onPickDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.tonal(
          onPressed: onPickDirectory,
          child: const Text('📁 Zielordner auswählen'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            selectedDir != null
                ? selectedDir!.split(Platform.pathSeparator).last
                : 'Kein Ordner ausgewählt',
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ExportProgressHeader extends StatelessWidget {
  final String currentTable;
  final int tableIndex;
  final int totalTables;

  const _ExportProgressHeader({
    required this.currentTable,
    required this.tableIndex,
    required this.totalTables,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.table_chart, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Exportiere Tabelle ${tableIndex + 1}/$totalTables: $currentTable',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ExportProgressSection extends StatelessWidget {
  final double progress;
  final VoidCallback onCancel;

  const _ExportProgressSection({
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (progress * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            Text('$percentage%'),
          ],
        ),
      ),
    );
  }
}

class _ExportResultCard extends StatelessWidget {
  final BulkExportResult result;

  const _ExportResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = result.success;

    return Card(
      color: success
          ? Colors.green.withValues(alpha: 0.1)
          : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.warning,
              color: success ? Colors.green : theme.colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              success ? 'Export erfolgreich' : 'Export mit Fehlern',
              style: theme.textTheme.titleMedium,
            ),
            if (result.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                result.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            ...result.tableResults.map(
              (tableResult) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      tableResult.success ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: tableResult.success
                          ? Colors.green
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tableResult.fileName,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${tableResult.exportedRows} Datensätze',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gesamt: ${result.totalExportedRows} Datensätze exportiert',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
