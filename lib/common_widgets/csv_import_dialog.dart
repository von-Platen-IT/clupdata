import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/data/csv_import_service.dart';
import '../core/database/database.dart';
import '../core/providers/database_provider.dart';
import 'database_backup_dialog.dart';

/// Zeigt den CSV-Import-Dialog an.
///
/// Wird aus dem Hauptmenü (Datenübertragung → Import → CSV Import) aufgerufen.
Future<void> showCsvImportDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const _CsvImportDialog(),
  );
}

/// Modal-Dialog für den CSV-Import.
///
/// Ablauf:
/// 1. Zieltabelle wählen (Dropdown)
/// 2. CSV-Datei wählen (FilePicker)
/// 3. Import-Modus wählen (Überschreiben/Anfügen)
/// 4. Automatische Validierung
/// 5. Import starten
class _CsvImportDialog extends HookConsumerWidget {
  const _CsvImportDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(appDatabaseProvider);

    // State
    final tablesFuture = useMemoized(
      () => CsvImportService.getImportableTables(db),
    );
    final tablesSnapshot = useFuture(tablesFuture);
    final selectedTable = useState<TableSchema?>(null);
    final filePath = useState<String?>(null);
    final fileName = useState<String?>(null);
    final importMode = useState(ImportMode.append);
    final validationResult = useState<CsvValidationResult?>(null);
    final isValidating = useState(false);
    final isImporting = useState(false);
    final importResult = useState<CsvImportResult?>(null);

    final canImport =
        validationResult.value?.isValid == true &&
        !isImporting.value &&
        !isValidating.value;

    return AlertDialog(
      title: const Text('CSV Import'),
      constraints: const BoxConstraints(maxWidth: 560),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warnung: Backup empfohlen
            _BackupWarning(tablesSnapshot: tablesSnapshot),
            const SizedBox(height: 16),

            // Zieltabelle
            _TableDropdown(
              tablesSnapshot: tablesSnapshot,
              selectedTable: selectedTable,
              onChanged: (table) {
                selectedTable.value = table;
                // Reset bei Tabellenwechsel
                filePath.value = null;
                fileName.value = null;
                validationResult.value = null;
                importResult.value = null;
              },
            ),
            const SizedBox(height: 12),

            // CSV-Datei
            _FilePickerRow(
              fileName: fileName.value,
              onPicked: (path, name) {
                filePath.value = path;
                fileName.value = name;
                validationResult.value = null;
                importResult.value = null;
              },
            ),
            const SizedBox(height: 12),

            // Import-Modus
            _ImportModeSelector(
              mode: importMode.value,
              onChanged: (mode) {
                importMode.value = mode;
                importResult.value = null;
              },
            ),
            const SizedBox(height: 16),

            // Validierungsergebnis
            if (isValidating.value)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (validationResult.value != null)
              _ValidationResultView(result: validationResult.value!),

            // Import-Ergebnis
            if (importResult.value != null) ...[
              const SizedBox(height: 12),
              _ImportResultView(result: importResult.value!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isImporting.value
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        // Validieren-Button
        if (filePath.value != null && selectedTable.value != null)
          FilledButton.tonal(
            onPressed: isValidating.value || isImporting.value
                ? null
                : () => _validate(
                    context: context,
                    db: db,
                    filePath: filePath.value!,
                    schema: selectedTable.value!,
                    isValidating: isValidating,
                    validationResult: validationResult,
                    importResult: importResult,
                  ),
            child: const Text('Validieren'),
          ),
        // Import-Button
        FilledButton(
          onPressed: canImport
              ? () => _import(
                  context: context,
                  db: db,
                  filePath: filePath.value!,
                  schema: selectedTable.value!,
                  mode: importMode.value,
                  isImporting: isImporting,
                  importResult: importResult,
                  ref: ref,
                )
              : null,
          child: isImporting.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Importieren'),
        ),
      ],
    );
  }

  /// Führt die Validierung durch.
  Future<void> _validate({
    required BuildContext context,
    required dynamic db,
    required String filePath,
    required TableSchema schema,
    required ValueNotifier<bool> isValidating,
    required ValueNotifier<CsvValidationResult?> validationResult,
    required ValueNotifier<CsvImportResult?> importResult,
  }) async {
    isValidating.value = true;
    importResult.value = null;

    try {
      final result = await CsvImportService.validateCsv(filePath, schema);
      validationResult.value = result;
    } finally {
      isValidating.value = false;
    }
  }

  /// Führt den Import durch.
  Future<void> _import({
    required BuildContext context,
    required AppDatabase db,
    required String filePath,
    required TableSchema schema,
    required ImportMode mode,
    required ValueNotifier<bool> isImporting,
    required ValueNotifier<CsvImportResult?> importResult,
    required WidgetRef ref,
  }) async {
    // Bei Überschreiben: zusätzliche Bestätigung
    if (mode == ImportMode.overwrite) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Daten überschreiben?'),
          content: Text(
            'Alle vorhandenen Daten in der Tabelle "${schema.displayName}" '
            'werden gelöscht und durch die CSV-Daten ersetzt.\n\n'
            'Möchten Sie fortfahren?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Überschreiben'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    isImporting.value = true;

    try {
      final result = await CsvImportService.importCsv(
        filePath,
        schema,
        mode,
        db,
      );
      importResult.value = result;

      if (result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.importedRows} Zeilen importiert')),
        );
      }
    } finally {
      isImporting.value = false;
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-Widgets
// ---------------------------------------------------------------------------

/// Warnbanner mit Backup-Empfehlung.
class _BackupWarning extends ConsumerWidget {
  final AsyncSnapshot<List<TableSchema>> tablesSnapshot;

  const _BackupWarning({required this.tablesSnapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.3),
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
          const SizedBox(width: 8),
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

/// Dropdown zur Auswahl der Zieltabelle.
class _TableDropdown extends StatelessWidget {
  final AsyncSnapshot<List<TableSchema>> tablesSnapshot;
  final ValueNotifier<TableSchema?> selectedTable;
  final ValueChanged<TableSchema?> onChanged;

  const _TableDropdown({
    required this.tablesSnapshot,
    required this.selectedTable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (tablesSnapshot.hasError) {
      return Text('Fehler: ${tablesSnapshot.error}');
    }

    if (!tablesSnapshot.hasData) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final tables = tablesSnapshot.data!;

    return DropdownButtonFormField<TableSchema>(
      initialValue: selectedTable.value,
      decoration: const InputDecoration(
        labelText: 'Zieltabelle',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: tables
          .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Zeile mit FilePicker-Button und Dateinamen-Anzeige.
class _FilePickerRow extends StatelessWidget {
  final String? fileName;
  final void Function(String path, String name) onPicked;

  const _FilePickerRow({required this.fileName, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            fileName ?? 'Keine Datei ausgewählt',
            style: TextStyle(
              fontStyle: fileName == null ? FontStyle.italic : FontStyle.normal,
              color: fileName == null
                  ? Theme.of(context).hintColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _pickFile,
          child: const Text('Datei auswählen'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'CSV-Datei auswählen',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    onPicked(path, result.files.single.name);
  }
}

/// Radio-Buttons für den Import-Modus.
class _ImportModeSelector extends StatelessWidget {
  final ImportMode mode;
  final ValueChanged<ImportMode> onChanged;

  const _ImportModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Import-Modus', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        RadioGroup<ImportMode>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Row(
            children: [
              Radio<ImportMode>(value: ImportMode.append),
              const Text('Anfügen'),
              const SizedBox(width: 16),
              Radio<ImportMode>(value: ImportMode.overwrite),
              const Text('Überschreiben'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Anzeige des Validierungsergebnisses.
class _ValidationResultView extends StatelessWidget {
  final CsvValidationResult result;

  const _ValidationResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.isValid
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.isValid
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                result.isValid ? Icons.check_circle : Icons.error,
                size: 18,
                color: result.isValid
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                result.isValid
                    ? 'Validierung erfolgreich'
                    : 'Validierung fehlgeschlagen',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: result.isValid
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Statistiken
          if (result.matchedColumnCount > 0)
            _infoRow(
              context,
              Icons.check,
              'Spalten erkannt: ${result.matchedColumnCount}',
            ),
          if (result.rowCount > 0)
            _infoRow(context, Icons.table_rows, 'Zeilen: ${result.rowCount}'),

          // Warnungen
          for (final warning in result.warnings)
            _infoRow(context, Icons.warning_amber, warning, isWarning: true),

          // Fehler
          for (final error in result.errors)
            _infoRow(context, Icons.error_outline, error, isError: true),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String text, {
    bool isWarning = false,
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    Color color = theme.colorScheme.onSurfaceVariant;
    if (isError) color = theme.colorScheme.error;
    if (isWarning) color = theme.colorScheme.tertiary;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anzeige des Import-Ergebnisses.
class _ImportResultView extends StatelessWidget {
  final CsvImportResult result;

  const _ImportResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error,
            color: result.success
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.success
                  ? '${result.importedRows} Zeilen erfolgreich importiert'
                  : result.errorMessage ?? 'Import fehlgeschlagen',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: result.success
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
