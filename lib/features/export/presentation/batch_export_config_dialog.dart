import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/models/data_grid_meta_state.dart';
import '../domain/batch_export_config.dart';

/// Dialog for configuring batch export operations.
///
/// Allows users to select:
/// - Which records to export (all or filtered)
/// - Optional date range filter
/// - Output mode (individual files, combined PDF, or print)
/// - Output directory
/// - Whether to include a summary page
class BatchExportConfigDialog extends StatefulWidget {
  /// Entity type to export
  final String entityType;

  /// Display name for the entity type
  final String entityDisplayName;

  /// Current meta state for filtering
  final DataGridMetaState metaState;

  /// Estimated count of items to export (before date filter)
  final int estimatedItemCount;

  const BatchExportConfigDialog({
    super.key,
    required this.entityType,
    required this.entityDisplayName,
    required this.metaState,
    required this.estimatedItemCount,
  });

  /// Shows the dialog and returns the configured [BatchExportConfig] or null.
  static Future<BatchExportConfig?> show(
    BuildContext context, {
    required String entityType,
    required String entityDisplayName,
    required DataGridMetaState metaState,
    required int estimatedItemCount,
  }) {
    return showDialog<BatchExportConfig>(
      context: context,
      builder: (context) => BatchExportConfigDialog(
        entityType: entityType,
        entityDisplayName: entityDisplayName,
        metaState: metaState,
        estimatedItemCount: estimatedItemCount,
      ),
    );
  }

  @override
  State<BatchExportConfigDialog> createState() =>
      _BatchExportConfigDialogState();
}

class _BatchExportConfigDialogState extends State<BatchExportConfigDialog> {
  bool _useDateRange = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  BatchExportOutputMode _outputMode = BatchExportOutputMode.combinedPdf;
  bool _includeSummary = true;
  String _outputDirectory = '';
  bool _isExporting = false;
  int _exportProgress = 0;
  int _exportTotal = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_download_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text('Batch-Export: ${widget.entityDisplayName}'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item count info
              _buildItemCountInfo(theme),
              const SizedBox(height: 24),

              // Date range section
              _buildDateRangeSection(theme),
              const SizedBox(height: 24),

              // Output mode section
              _buildOutputModeSection(theme),
              const SizedBox(height: 24),

              // Summary section
              _buildSummarySection(theme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        if (_isExporting)
          SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _exportTotal > 0 ? _exportProgress / _exportTotal : null,
                ),
                const SizedBox(height: 4),
                Text(
                  '$_exportProgress / $_exportTotal',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          )
        else
          FilledButton.icon(
            onPressed: _canExport ? _handleExport : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Exportieren'),
          ),
      ],
    );
  }

  Widget _buildItemCountInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Geschätzt ${widget.estimatedItemCount} Datensätze verfügbar',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection(ThemeData theme) {
    final hasDateField = _entityHasDateField();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zeitraum',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (!hasDateField)
          Text(
            'Kein Datumsfeld für diesen Entitätstyp verfügbar',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          CheckboxListTile(
            title: const Text('Zeitraum einschränken'),
            subtitle: const Text('Optional: Export auf Zeitraum begrenzen'),
            value: _useDateRange,
            onChanged: (value) => setState(() => _useDateRange = value ?? false),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          if (_useDateRange) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'Von',
                    selectedDate: _dateFrom,
                    onDateSelected: (date) => setState(() => _dateFrom = date),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DatePickerField(
                    label: 'Bis',
                    selectedDate: _dateTo,
                    onDateSelected: (date) => setState(() => _dateTo = date),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildOutputModeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ausgabe',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        RadioListTile<BatchExportOutputMode>(
          title: const Text('Alle in einer PDF-Datei kombinieren'),
          value: BatchExportOutputMode.combinedPdf,
          groupValue: _outputMode,
          onChanged: (value) => setState(() => _outputMode = value!),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<BatchExportOutputMode>(
          title: const Text('Einzelne PDF-Dateien pro Datensatz'),
          value: BatchExportOutputMode.individualFiles,
          groupValue: _outputMode,
          onChanged: (value) => setState(() => _outputMode = value!),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<BatchExportOutputMode>(
          title: const Text('Direkt drucken'),
          value: BatchExportOutputMode.printDirect,
          groupValue: _outputMode,
          onChanged: (value) => setState(() => _outputMode = value!),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (_outputMode != BatchExportOutputMode.printDirect) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _selectOutputDirectory,
            icon: const Icon(Icons.folder_open),
            label: Text(
              _outputDirectory.isEmpty
                  ? 'Ausgabe-Verzeichnis wählen'
                  : _outputDirectory,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummarySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zusammenfassung',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Zusammenfassungs-Seite einfügen'),
          subtitle: const Text('Statistiken und Übersichten am Ende der PDF'),
          value: _includeSummary,
          onChanged: (value) => setState(() => _includeSummary = value ?? true),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  bool _entityHasDateField() {
    switch (widget.entityType.toLowerCase()) {
      case 'mitglied':
      case 'rechnung':
      case 'beitrag':
        return true;
      default:
        return false;
    }
  }

  bool get _canExport {
    if (_isExporting) return false;
    if (_outputMode != BatchExportOutputMode.printDirect &&
        _outputDirectory.isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _selectOutputDirectory() async {
    final directory = await FilePicker.platform.getDirectoryPath();
    if (directory != null) {
      setState(() => _outputDirectory = directory);
    }
  }

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0;
      _exportTotal = widget.estimatedItemCount;
    });

    // Create the config
    final config = BatchExportConfig(
      entityType: widget.entityType,
      metaState: widget.metaState,
      outputDirectory: _outputDirectory,
      outputMode: _outputMode,
      dateFrom: _useDateRange ? _dateFrom : null,
      dateTo: _useDateRange ? _dateTo : null,
      includeSummary: _includeSummary,
      printDirectly: _outputMode == BatchExportOutputMode.printDirect,
    );

    // Return the config to the caller
    if (mounted) {
      Navigator.of(context).pop(config);
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;

  const _DatePickerField({
    required this.label,
    this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
      icon: const Icon(Icons.calendar_today),
      label: Text(
        selectedDate != null
            ? '${selectedDate!.day.toString().padLeft(2, '0')}.'
                '${selectedDate!.month.toString().padLeft(2, '0')}.'
                '${selectedDate!.year}'
            : label,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 40),
      ),
    );
  }
}
