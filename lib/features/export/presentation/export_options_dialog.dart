import 'package:flutter/material.dart';

import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_preview_dialog.dart';

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
  Future<void> _handleExport() async {
    Navigator.of(context).pop();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('PDF wird vorbereitet...'),
          ],
        ),
      ),
    );

    try {
      final exporter = PdfExporter();
      PdfExportData exportData;

      switch (_selectedOption) {
        case ExportOption.currentView:
          exportData = await _prepareCurrentViewExport(exporter);
          break;
        case ExportOption.allDetails:
          exportData = await _prepareAllDetailsExport(exporter);
          break;
        case ExportOption.fullExport:
          exportData = await _prepareFullExport(exporter);
          break;
      }

      // Hide loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show preview dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => PdfPreviewDialog(exportData: exportData),
        );
      }
    } catch (e) {
      // Hide loading
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Export: $e')));
      }
    }
  }

  /// Prepares export for current view (visible columns only).
  Future<PdfExportData> _prepareCurrentViewExport(PdfExporter exporter) async {
    final ctx = widget.contextData;

    if (ctx.isList && ctx.controller != null) {
      // List export with visible columns
      return exporter.prepareListExport(
        ctx.controller!,
        title: ctx.title,
        entityName: ctx.entityType,
        visibleOnly: true,
      );
    } else {
      // Detail export with current view
      return exporter.prepareDetailExport(
        ctx.controller!,
        ctx.item,
        title: ctx.title,
        entityName: ctx.entityType,
      );
    }
  }

  /// Prepares export with all available fields.
  Future<PdfExportData> _prepareAllDetailsExport(PdfExporter exporter) async {
    final ctx = widget.contextData;

    if (ctx.isList && ctx.controller != null) {
      // List export with all columns
      return exporter.prepareListExport(
        ctx.controller!,
        title: '${ctx.title} - Alle Details',
        entityName: ctx.entityType,
        visibleOnly: false,
      );
    } else {
      // Detail export with all fields
      return exporter.prepareDetailExport(
        ctx.controller!,
        ctx.item,
        title: '${ctx.title} - Alle Details',
        entityName: ctx.entityType,
      );
    }
  }

  /// Prepares full export including relations.
  Future<PdfExportData> _prepareFullExport(PdfExporter exporter) async {
    final ctx = widget.contextData;

    // For now, same as all details
    // TODO: Implement full export with relations
    return _prepareAllDetailsExport(exporter);
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
