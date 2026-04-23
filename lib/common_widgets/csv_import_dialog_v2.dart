import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/data/csv_import_service_v2.dart';
import '../core/providers/database_provider.dart';
import 'database_backup_dialog.dart';

/// Zeigt den CSV-Import-Dialog (V2) an.
Future<void> showCsvImportDialogV2(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const _CsvImportDialogV2(),
  );
}

/// CSV Import Dialog mit Progress-Anzeige und Streaming.
class _CsvImportDialogV2 extends HookConsumerWidget {
  const _CsvImportDialogV2();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(appDatabaseProvider);

    // State
    final tablesFuture = useMemoized(
      () => CsvImportServiceV2.getImportableTables(db),
    );
    final tablesSnapshot = useFuture(tablesFuture);

    final selectedFile = useState<PlatformFile?>(null);
    final selectedTable = useState<TableSchema?>(null);
    final fileAnalysis = useState<Map<String, dynamic>?>(null);
    final importMode = useState(ImportMode.append);

    // Import State
    final isImporting = useState(false);
    final importProgress = useState(0.0);
    final importedRows = useState(0);
    final totalRows = useState(0);
    final failedRows = useState(0);
    final importResult = useState<CsvImportResult?>(null);
    final validationErrors = useState<List<String>>([]);

    // Cancel token
    final cancelToken = useState<bool>(false);

    // Cleanup
    useEffect(() {
      return () {
        cancelToken.value = true;
      };
    }, []);

    Future<void> pickFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        selectedFile.value = result.files.single;

        // Datei analysieren
        try {
          final analysis = await CsvImportServiceV2.analyzeFile(
            result.files.single.path!,
          );
          fileAnalysis.value = analysis;
          totalRows.value = analysis['estimatedRows'] as int;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Lesen der Datei: $e')),
          );
        }
      }
    }

    Future<void> startImport() async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $e')));
      } finally {
        isImporting.value = false;
      }
    }

    void cancelImport() {
      cancelToken.value = true;
      isImporting.value = false;
    }

    return AlertDialog(
      title: const Text('CSV Import'),
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 800),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Backup Warnung
              _BackupWarning(tablesSnapshot: tablesSnapshot),
              const SizedBox(height: 16),

              // Datei-Auswahl
              _FilePickerSection(
                selectedFile: selectedFile.value,
                onPickFile: pickFile,
              ),

              // Datei-Analyse
              if (fileAnalysis.value != null) ...[
                const SizedBox(height: 12),
                _FileAnalysisCard(analysis: fileAnalysis.value!),
              ],

              const SizedBox(height: 16),

              // Tabellen-Auswahl
              if (selectedFile.value != null)
                _TableDropdown(
                  tablesSnapshot: tablesSnapshot,
                  selectedTable: selectedTable,
                  onChanged: (table) => selectedTable.value = table,
                ),

              const SizedBox(height: 12),

              // Import-Modus
              if (selectedTable.value != null)
                _ImportModeSelector(
                  mode: importMode.value,
                  onChanged: (mode) => importMode.value = mode,
                ),

              const SizedBox(height: 16),

              // Progress-Anzeige
              if (isImporting.value) ...[
                _ImportProgressSection(
                  progress: importProgress.value,
                  importedRows: importedRows.value,
                  totalRows: totalRows.value,
                  failedRows: failedRows.value,
                  onCancel: cancelImport,
                ),
              ],

              // Fehler-Anzeige
              if (validationErrors.value.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ErrorList(errors: validationErrors.value),
              ],

              // Ergebnis-Anzeige
              if (importResult.value != null) ...[
                const SizedBox(height: 12),
                _ImportResultCard(result: importResult.value!),
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
          TextButton(onPressed: cancelImport, child: const Text('Abbrechen'))
        else if (selectedFile.value != null &&
            selectedTable.value != null &&
            importResult.value == null)
          FilledButton(
            onPressed: startImport,
            child: const Text('Importieren'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-Widgets
// ---------------------------------------------------------------------------

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
          ? Colors.green.withOpacity(0.1)
          : theme.colorScheme.errorContainer.withOpacity(0.3),
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
