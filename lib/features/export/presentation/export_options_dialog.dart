import 'package:flutter/material.dart';

import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';


/// Dialog for selecting export options before creating a PDF.
///
/// This dialog allows users to choose what data to export:
/// - Current view (visible columns only)
/// - All details (all available fields)
/// - Full export (with relations)
///
/// It also shows a preview of what will be exported.
class ExportOptionsDialog extends StatefulWidget {
  /// The export context data.
  final ExportContextData contextData;

  const ExportOptionsDialog({super.key, required this.contextData});

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  ExportOption _selectedOption = ExportOption.currentView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDetail = widget.contextData.isDetail;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('PDF Export'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context info
            _buildContextInfo(theme),
            const SizedBox(height: 24),
            // Export options
            Text(
              'Was möchten Sie exportieren?',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ..._buildExportOptions(isDetail),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: _handleExport,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Weiter'),
        ),
      ],
    );
  }

  /// Builds the context information section.
  Widget _buildContextInfo(ThemeData theme) {
    final ctx = widget.contextData;
    final isDetail = ctx.isDetail;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDetail ? Icons.person : Icons.list,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ctx.title,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (ctx.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              ctx.subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Chip(
            label: Text(
              isDetail ? 'Detail-Ansicht' : 'Listen-Ansicht',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            backgroundColor: theme.colorScheme.secondaryContainer,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// Builds the export option radio buttons.
  List<Widget> _buildExportOptions(bool isDetail) {
    final options = <Widget>[];

    // Option 1: Current view (always available)
    options.add(
      _ExportOptionTile(
        title: isDetail ? 'Aktuelle Ansicht' : 'Sichtbare Spalten',
        subtitle: isDetail
            ? 'Nur die aktuell angezeigten Felder'
            : 'Nur die im Grid sichtbaren Spalten',
        icon: isDetail ? Icons.article_outlined : Icons.table_rows_outlined,
        value: ExportOption.currentView,
        groupValue: _selectedOption,
        onChanged: (value) => setState(() => _selectedOption = value!),
      ),
    );

    // Option 2: All details (always available)
    options.add(
      _ExportOptionTile(
        title: 'Alle Details',
        subtitle: isDetail
            ? 'Alle verfügbaren Felder dieses Datensatzes'
            : 'Alle verfügbaren Spalten für alle Datensätze',
        icon: Icons.description_outlined,
        value: ExportOption.allDetails,
        groupValue: _selectedOption,
        onChanged: (value) => setState(() => _selectedOption = value!),
      ),
    );

    // Option 3: Full export with relations (detail only)
    if (isDetail) {
      options.add(
        _ExportOptionTile(
          title: 'Kompletter Datensatz',
          subtitle: 'Inklusive verknüpfter Daten (Rechnungen, Beiträge, etc.)',
          icon: Icons.folder_copy_outlined,
          value: ExportOption.fullExport,
          groupValue: _selectedOption,
          onChanged: (value) => setState(() => _selectedOption = value!),
        ),
      );
    }

    return options;
  }

  /// Handles the export based on selected option.
  void _handleExport() {
    try {
      final exporter = PdfExporter();
      PdfExportData exportData;

      switch (_selectedOption) {
        case ExportOption.currentView:
          exportData = exporter.prepareExport(widget.contextData, useFullTable: false);
          break;
        case ExportOption.allDetails:
        case ExportOption.fullExport:
          exportData = exporter.prepareExport(widget.contextData, useFullTable: true);
          break;
      }

      Navigator.of(context).pop(exportData);
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Export: $e')),
      );
    }
  }
}

/// Enum representing the export options.
enum ExportOption { currentView, allDetails, fullExport }

/// Widget for a single export option tile.
class _ExportOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ExportOption value;
  final ExportOption groupValue;
  final ValueChanged<ExportOption?> onChanged;

  const _ExportOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == groupValue;

    return RadioListTile<ExportOption>(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      secondary: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
