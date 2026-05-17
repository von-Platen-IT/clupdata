import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/active_data_grid_provider.dart';
import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_preview_dialog.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';
import '../services/dialog_export_helper.dart';
import 'export_options_dialog.dart';

/// A button that provides export functionality for detail dialogs.
///
/// This button should be placed in the actions section of a detail dialog
/// to allow users to export/print the current item.
///
/// Example usage in a dialog:
/// ```dart
/// AppEditDialogScaffold(
///   title: 'Mitglied bearbeiten',
///   actions: [
///     DialogExportButton(
///       item: member,
///       entityType: 'mitglied',
///       title: 'Mitglied ${member.name}',
///     ),
///   ],
///   child: ...,
/// )
/// ```
class DialogExportButton extends ConsumerWidget {
  /// The item to export.
  final dynamic item;

  /// The entity type identifier (e.g., 'mitglied', 'rechnung').
  final String entityType;

  /// The display title for the export.
  final String title;

  /// Optional subtitle or description.
  final String? subtitle;

  /// Optional icon size.
  final double iconSize;

  /// Optional tooltip.
  final String? tooltip;

  const DialogExportButton({
    super.key,
    required this.item,
    required this.entityType,
    required this.title,
    this.subtitle,
    this.iconSize = 20,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.picture_as_pdf_outlined, size: iconSize),
      tooltip: tooltip ?? 'Als PDF exportieren',
      onPressed: () => _handleExport(context, ref),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(activeDataGridControllerProvider);
    if (controller == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler: Kein aktiver DataGrid-Controller gefunden.')),
        );
      }
      return;
    }

    final exportContext = DialogExportHelper.buildDetailExportContext(
      item: item,
      entityType: entityType,
      title: title,
      subtitle: subtitle,
      controller: controller,
    );

    await showDialog(
      context: context,
      builder: (_) => ExportOptionsDialog(contextData: exportContext),
    );
  }
}

/// A dropdown button that provides multiple export options for detail dialogs.
///
/// This is useful when you want to offer different export formats (PDF, Print, etc.)
class DialogExportMenuButton extends ConsumerWidget {
  /// The item to export.
  final dynamic item;

  /// The entity type identifier (e.g., 'mitglied', 'rechnung').
  final String entityType;

  /// The display title for the export.
  final String title;

  /// Optional subtitle or description.
  final String? subtitle;

  /// Optional icon size.
  final double iconSize;

  const DialogExportMenuButton({
    super.key,
    required this.item,
    required this.entityType,
    required this.title,
    this.subtitle,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: iconSize),
      tooltip: 'Export-Optionen',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Als PDF exportieren'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'print',
          child: Row(
            children: [
              Icon(
                Icons.print_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Drucken'),
            ],
          ),
        ),
      ],
      onSelected: (value) => _handleSelection(context, ref, value),
    );
  }

  Future<void> _handleSelection(BuildContext context, WidgetRef ref, String value) async {
    final controller = ref.read(activeDataGridControllerProvider);
    if (controller == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler: Kein aktiver DataGrid-Controller gefunden.')),
        );
      }
      return;
    }

    final exportContext = DialogExportHelper.buildDetailExportContext(
      item: item,
      entityType: entityType,
      title: title,
      subtitle: subtitle,
      controller: controller,
    );

    switch (value) {
      case 'pdf':
        final exportData = await showDialog<PdfExportData>(
          context: context,
          builder: (_) => ExportOptionsDialog(contextData: exportContext),
        );
        if (exportData != null && context.mounted) {
          await showDialog(
            context: context,
            builder: (_) => PdfPreviewDialog(exportData: exportData),
          );
        }
        break;
      case 'print':
        await _handlePrint(context, exportContext);
        break;
    }
  }

  Future<void> _handlePrint(BuildContext context, ExportContextData exportContext) async {
    try {
      final exporter = PdfExporter(template: PdfTemplateRegistry.simple);
      final pdfBytes = await exporter.export(exportContext, useFullTable: false);

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${exportContext.title} Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Drucken: $e')),
        );
      }
    }
  }
}
