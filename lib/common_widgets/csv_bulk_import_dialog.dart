import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/data/csv_import_service_v2.dart';
import '../core/providers/database_provider.dart';
import 'database_backup_dialog.dart';

/// Zeigt den CSV Bulk-Import-Dialog an.
///
/// Ermöglicht den Import einzelner Tabellen oder aller Tabellen
/// aus einem Ordner (Bulk-Import mit korrekter Reihenfolge).
Future<void> showCsvBulkImportDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const _CsvBulkImportDialog(),
  );
}

/// CSV Bulk-Import Dialog.
///
/// Features:
/// - Einzel-Import: Eine CSV-Datei → eine Tabelle
/// - Bulk-Import: Ordner mit CSV-Dateien → alle Tabellen in Reihenfolge
/// - Automatische Tabellen-Erkennung anhand des Dateinamens
/// - Warnung bei fehlenden Tabellen
/// - Progress-Anzeige pro Tabelle und gesamt
class _CsvBulkImportDialog extends HookConsumerWidget {
  const _CsvBulkImportDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(appDatabaseProvider);

    // Tabellen-Schemas laden
    final tablesFuture = useMemoized(
      () => CsvImportServiceV2.getImportableTables(db),
    );
    final tablesSnapshot = useFuture(tablesFuture);

    // Import-Modus
    final importMode = useState(ImportMode.append);

    // Bulk-Import State
    final selectedDir = useState<String?>(null);
    final detectedFiles = useState<Map<String, String>>({}); // table → filePath
    final missingTables = useState<List<String>>([]);

    // Single-Import State
    final selectedFile = useState<PlatformFile?>(null);
    final selectedTable = useState<TableSchema?>(null);
    final fileAnalysis = useState<Map<String, dynamic>?>(null);

    // Gemeinsamer Import State
    final isImporting = useState(false);
    final importProgress = useState(0.0);
    final importedRows = useState(0);
    final totalRows = useState(0);
    final failedRows = useState(0);
    final importResult = useState<CsvImportResult?>(null);
    final bulkImportResult = useState<BulkImportResult?>(null);
    final validationErrors = useState<List<String>>([]);

    // Bulk-Progress State
    final currentBulkTable = useState<String>('');
    final currentBulkTableIndex = useState(0);
    final totalBulkTables = useState(0);

    // Cancel token
    final cancelToken = useState<bool>(false);

    useEffect(() {
      return () {
        cancelToken.value = true;
      };
    }, []);

    // -----------------------------------------------------------------------
    // Ordner auswählen (Bulk)
    // -----------------------------------------------------------------------
    Future<void> pickDirectory() async {
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Ordner mit CSV-Dateien auswählen',
      );

      if (dir == null) return;

      selectedDir.value = dir;
      final detected = _scanDirectoryForCsvFiles(dir);
      detectedFiles.value = detected;
      missingTables.value = CsvImportServiceV2.findMissingTables(detected);
    }

    // -----------------------------------------------------------------------
    // Einzel-Datei auswählen (Single)
    // -----------------------------------------------------------------------
    Future<void> pickFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        selectedFile.value = result.files.single;

        try {
          final analysis = await CsvImportServiceV2.analyzeFile(
            result.files.single.path!,
          );
          fileAnalysis.value = analysis;
          totalRows.value = analysis['estimatedRows'] as int;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Fehler beim Lesen der Datei: $e')),
            );
          }
        }
      }
    }

    // -----------------------------------------------------------------------
    // Single-Import starten
    // -----------------------------------------------------------------------
    Future<void> startSingleImport() async {
      if (selectedFile.value?.path == null || selectedTable.value == null) {
        return;
      }

      isImporting.value = true;
      importProgress.value = 0.0;
      importedRows.value = 0;
      failedRows.value = 0;
      validationErrors.value = [];
      cancelToken.value = false;

      try {
        final result = await CsvImportServiceV2.importFile(
          selectedFile.value!.path!,
          selectedTable.value!,
          importMode.value,
          db,
          batchSize: 100,
          onProgress: (processed, total) {
            if (!cancelToken.value) {
              importedRows.value = processed;
              importProgress.value = total > 0 ? processed / total : 0;
            }
          },
          onRowError: (rowIndex, error) {
            failedRows.value++;
            if (validationErrors.value.length < 10) {
              validationErrors.value = [
                ...validationErrors.value,
                'Zeile $rowIndex: $error',
              ];
            }
          },
        );

        importResult.value = result;
      } catch (e) {
        if (!cancelToken.value && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $e')));
        }
      } finally {
        isImporting.value = false;
      }
    }

    // -----------------------------------------------------------------------
    // Bulk-Import starten
    // -----------------------------------------------------------------------
    Future<void> startBulkImport() async {
      if (detectedFiles.value.isEmpty) return;

      isImporting.value = true;
      importProgress.value = 0.0;
      importedRows.value = 0;
      failedRows.value = 0;
      validationErrors.value = [];
      bulkImportResult.value = null;
      cancelToken.value = false;

      totalBulkTables.value = detectedFiles.value.length;

      try {
        final result = await CsvImportServiceV2.importMultipleFiles(
          detectedFiles.value,
          importMode.value,
          db,
          batchSize: 100,
          onProgress:
              ({
                required String currentTable,
                required int tableIndex,
                required int totalTables,
                required double tableProgress,
                required int tableImportedRows,
                required int tableTotalRows,
              }) {
                if (!cancelToken.value) {
                  currentBulkTable.value = currentTable;
                  currentBulkTableIndex.value = tableIndex;
                  final overallProgress =
                      (tableIndex + tableProgress) / totalTables;
                  importProgress.value = overallProgress;
                  importedRows.value = tableImportedRows;
                }
              },
        );

        bulkImportResult.value = result;
      } catch (e) {
        if (!cancelToken.value && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bulk-Import fehlgeschlagen: $e')),
          );
        }
      } finally {
        isImporting.value = false;
      }
    }

    // -----------------------------------------------------------------------
    // Cancel
    // -----------------------------------------------------------------------
    void cancelImport() {
      cancelToken.value = true;
      isImporting.value = false;
    }

    // -----------------------------------------------------------------------
    // UI
    // -----------------------------------------------------------------------
    final hasSingleSelection =
        selectedFile.value != null && selectedTable.value != null;
    final hasBulkSelection = detectedFiles.value.isNotEmpty;
    final canStartBulk = hasBulkSelection && missingTables.value.isEmpty;

    return AlertDialog(
      title: const Text('CSV Import'),
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Backup Warnung
              _BackupWarning(tablesSnapshot: tablesSnapshot),
              const SizedBox(height: 16),

              // ---- Bulk Import Section ----
              _SectionHeader(title: 'Bulk-Import (Ordner)'),
              const SizedBox(height: 8),
              _DirectoryPickerSection(
                selectedDir: selectedDir.value,
                onPickDirectory: pickDirectory,
              ),

              if (detectedFiles.value.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetectedFilesCard(
                  files: detectedFiles.value,
                  missingTables: missingTables.value,
                ),
              ],

              const SizedBox(height: 20),

              // ---- Single Import Section ----
              _SectionHeader(title: 'Einzel-Import (eine Datei)'),
              const SizedBox(height: 8),
              _FilePickerSection(
                selectedFile: selectedFile.value,
                onPickFile: pickFile,
              ),

              if (fileAnalysis.value != null) ...[
                const SizedBox(height: 8),
                _FileAnalysisCard(analysis: fileAnalysis.value!),
              ],

              if (selectedFile.value != null) ...[
                const SizedBox(height: 8),
                _TableDropdown(
                  tablesSnapshot: tablesSnapshot,
                  selectedTable: selectedTable,
                  onChanged: (table) => selectedTable.value = table,
                ),
              ],

              const SizedBox(height: 16),

              // ---- Import Mode ----
              _ImportModeSelector(
                mode: importMode.value,
                onChanged: (mode) => importMode.value = mode,
              ),

              const SizedBox(height: 16),

              // ---- Progress ----
              if (isImporting.value) ...[
                if (currentBulkTable.value.isNotEmpty)
                  _BulkProgressHeader(
                    currentTable: currentBulkTable.value,
                    tableIndex: currentBulkTableIndex.value,
                    totalTables: totalBulkTables.value,
                  ),
                _ImportProgressSection(
                  progress: importProgress.value,
                  importedRows: importedRows.value,
                  totalRows: totalRows.value,
                  failedRows: failedRows.value,
                  onCancel: cancelImport,
                ),
              ],

              // ---- Errors ----
              if (validationErrors.value.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ErrorList(errors: validationErrors.value),
              ],

              // ---- Single Result ----
              if (importResult.value != null) ...[
                const SizedBox(height: 8),
                _ImportResultCard(result: importResult.value!),
              ],

              // ---- Bulk Result ----
              if (bulkImportResult.value != null) ...[
                const SizedBox(height: 8),
                _BulkImportResultCard(result: bulkImportResult.value!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isImporting.value
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        if (isImporting.value)
          TextButton(onPressed: cancelImport, child: const Text('Abbrechen')),
        if (!isImporting.value && importResult.value == null)
          FilledButton(
            onPressed: hasSingleSelection ? startSingleImport : null,
            child: const Text('Einzel-Import'),
          ),
        if (!isImporting.value && importResult.value == null)
          FilledButton(
            onPressed: canStartBulk ? startBulkImport : null,
            child: const Text('Bulk-Import starten'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: Tabellenname aus Dateinamen erkennen
// ---------------------------------------------------------------------------

/// Bekannte Tabellen-Namen für die Dateinamens-Erkennung.
const _knownTableNames = [
  'bemerkung',
  'stammdaten',
  'preis',
  'leistung',
  'mitglied',
  'waren',
  'beitrag',
  'beitrag_status_verlauf',
  'rechnung',
  'rechnung_position',
];

/// Durchsucht einen Ordner nach CSV-Dateien und erkennt die Tabelle
/// anhand des Dateinamens.
Map<String, String> _scanDirectoryForCsvFiles(String dir) {
  final dirObj = Directory(dir);
  if (!dirObj.existsSync()) return {};

  final csvFiles = dirObj
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.csv'))
      .toList();

  final detected = <String, String>{};
  for (final file in csvFiles) {
    final fileName = file.uri.pathSegments.last;
    final tableName = fileName.replaceAll(RegExp(r'\.csv$'), '');
    // Nur bekannte Tabellen akzeptieren
    if (_knownTableNames.contains(tableName)) {
      detected[tableName] = file.path;
    }
  }

  return detected;
}

// ---------------------------------------------------------------------------
// Sub-Widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _BackupWarning extends ConsumerWidget {
  final AsyncSnapshot<List<TableSchema>> tablesSnapshot;

  const _BackupWarning({required this.tablesSnapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Empfehlung: Führen Sie vor dem Import eine Datensicherung durch.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          FilledButton.tonal(
            onPressed: tablesSnapshot.hasData
                ? () => showBackupDialog(context, ref)
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              textStyle: Theme.of(context).textTheme.labelSmall,
            ),
            child: const Text('Backup'),
          ),
        ],
      ),
    );
  }
}

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
          child: const Text('📁 Ordner auswählen'),
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

class _DetectedFilesCard extends StatelessWidget {
  final Map<String, String> files;
  final List<String> missingTables;

  const _DetectedFilesCard({required this.files, required this.missingTables});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gefundene CSV-Dateien', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            // Alle bekannten Tabellen in Reihenfolge anzeigen
            ..._knownTableNames.map((tableName) {
              final isFound = files.containsKey(tableName);
              final displayName = _tableDisplayName(tableName);

              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(
                      isFound ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isFound ? Colors.green : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isFound
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isFound) ...[
                      const Spacer(),
                      Text(
                        files[tableName]!.split(Platform.pathSeparator).last,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              );
            }),

            // Warnung bei fehlenden Tabellen
            if (missingTables.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Es fehlen CSV-Dateien für:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...missingTables.map(
                            (t) => Text(
                              '• ${_tableDisplayName(t)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Der Bulk-Import erfordert CSV-Dateien für alle '
                            'Tabellen, um FK-Constraint-Probleme zu vermeiden.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tableDisplayName(String tableName) {
    const names = <String, String>{
      'bemerkung': 'Bemerkungen',
      'stammdaten': 'Stammdaten',
      'preis': 'Preise',
      'leistung': 'Leistungen',
      'mitglied': 'Mitglieder',
      'waren': 'Waren',
      'beitrag': 'Beiträge',
      'beitrag_status_verlauf': 'Beitragsstatus-Verlauf',
      'rechnung': 'Rechnungen',
      'rechnung_position': 'Rechnungspositionen',
    };
    return names[tableName] ?? tableName;
  }
}

class _FilePickerSection extends StatelessWidget {
  final PlatformFile? selectedFile;
  final VoidCallback onPickFile;

  const _FilePickerSection({
    required this.selectedFile,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.tonal(
          onPressed: onPickFile,
          child: const Text('CSV-Datei wählen'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            selectedFile?.name ?? 'Keine Datei ausgewählt',
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FileAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const _FileAnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datei-Analyse', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Trennzeichen:',
              value: _delimiterDisplay(analysis['delimiter'] as String),
            ),
            _InfoRow(label: 'Spalten:', value: '${analysis['headerCount']}'),
            _InfoRow(
              label: 'Geschätzte Zeilen:',
              value: '${analysis['estimatedRows']}',
            ),
            const SizedBox(height: 8),
            Text(
              'Header: ${(analysis['headers'] as List).join(', ')}',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _delimiterDisplay(String delimiter) {
    switch (delimiter) {
      case ';':
        return 'Semikolon (;)';
      case ',':
        return 'Komma (,)';
      case '\t':
        return 'Tab';
      default:
        return '"$delimiter"';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TableDropdown extends StatelessWidget {
  final AsyncSnapshot<List<TableSchema>> tablesSnapshot;
  final ValueNotifier<TableSchema?> selectedTable;
  final void Function(TableSchema?) onChanged;

  const _TableDropdown({
    required this.tablesSnapshot,
    required this.selectedTable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (tablesSnapshot.connectionState == ConnectionState.waiting) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Tabellen werden geladen...'),
        ],
      );
    }

    if (!tablesSnapshot.hasData) {
      return const Text('Fehler beim Laden der Tabellen');
    }

    final tables = tablesSnapshot.data!;

    return DropdownButtonFormField<TableSchema>(
      initialValue: selectedTable.value,
      decoration: const InputDecoration(
        labelText: 'Zieltabelle',
        border: OutlineInputBorder(),
      ),
      hint: const Text('Tabelle auswählen'),
      isExpanded: true,
      items: tables.map((table) {
        return DropdownMenuItem(
          value: table,
          child: Text('${table.displayName} (${table.sqlTableName})'),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _ImportModeSelector extends StatelessWidget {
  final ImportMode mode;
  final ValueChanged<ImportMode> onChanged;

  const _ImportModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ImportMode>(
      segments: const [
        ButtonSegment(
          value: ImportMode.append,
          label: Text('Anfügen'),
          icon: Icon(Icons.add),
        ),
        ButtonSegment(
          value: ImportMode.overwrite,
          label: Text('Überschreiben'),
          icon: Icon(Icons.delete_outline),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _BulkProgressHeader extends StatelessWidget {
  final String currentTable;
  final int tableIndex;
  final int totalTables;

  const _BulkProgressHeader({
    required this.currentTable,
    required this.tableIndex,
    required this.totalTables,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.table_chart, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Importiere Tabelle ${tableIndex + 1}/$totalTables: $currentTable',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportProgressSection extends StatelessWidget {
  final double progress;
  final int importedRows;
  final int totalRows;
  final int failedRows;
  final VoidCallback onCancel;

  const _ImportProgressSection({
    required this.progress,
    required this.importedRows,
    required this.totalRows,
    required this.failedRows,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$percentage%'),
                Text(
                  '$importedRows / $totalRows Zeilen',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (failedRows > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$failedRows Fehler',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  final List<String> errors;

  const _ErrorList({required this.errors});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fehler:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            ...errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  '• $e',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportResultCard extends StatelessWidget {
  final CsvImportResult result;

  const _ImportResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = result.success && result.failedRows == 0;

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
              success ? 'Import erfolgreich' : 'Import mit Fehlern',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${result.importedRows} Zeilen importiert',
              style: theme.textTheme.bodyLarge,
            ),
            if (result.failedRows > 0)
              Text(
                '${result.failedRows} Zeilen fehlgeschlagen',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BulkImportResultCard extends StatelessWidget {
  final BulkImportResult result;

  const _BulkImportResultCard({required this.result});

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
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : theme.colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              success
                  ? 'Bulk-Import erfolgreich'
                  : 'Bulk-Import fehlgeschlagen',
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
                        tableResult.displayName,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${tableResult.importedRows} Zeilen'
                      '${tableResult.failedRows > 0 ? ", ${tableResult.failedRows} Fehler" : ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tableResult.failedRows > 0
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gesamt: ${result.totalImportedRows} Zeilen importiert'
              '${result.totalFailedRows > 0 ? ", ${result.totalFailedRows} fehlgeschlagen" : ""}',
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
