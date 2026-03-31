import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/data_grid_controller.dart';
import '../../../widgets/data_grid_v2/export/csv_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';
import '../domain/export_config.dart';
import 'export_options_dialog.dart';

/// A button that provides export functionality for list views (DataGrid).
///
/// Provides options to export to PDF, print, or CSV.
class ListExportMenuButton<T> extends StatelessWidget {
  /// The controller of the data grid to export.
  final DataGridController<T> controller;

  /// Configuration for the export (title, entity type).
  final ExportConfig config;

  /// Optional callback invoked immediately before any export action begins.
  ///
  /// Use this to synchronize transient UI state (e.g., column visibility
  /// from PlutoGrid's StateManager) into the controller before export.
  final void Function()? onBeforeExport;

  const ListExportMenuButton({
    super.key,
    required this.controller,
    required this.config,
    this.onBeforeExport,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(128),
          ),
        ),
        child: const Icon(Icons.more_vert),
      ),
      tooltip: 'Exportieren',
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
              const Text('Als PDF exportieren...'),
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
              const Text('Drucken...'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('CSV exportieren...'),
            ],
          ),
        ),
      ],
      onSelected: (value) => _handleSelection(context, value),
    );
  }

  Future<void> _handleSelection(BuildContext context, String value) async {
    // Sync transient UI state (hidden columns, etc.) before export.
    onBeforeExport?.call();

    final exportContext = ExportContextData(
      mode: ExportMode.list,
      controller: controller,
      entityType: config.entityType,
      title: config.title,
      subtitle: config.subtitle,
    );

    switch (value) {
      case 'pdf':
        await showDialog(
          context: context,
          builder: (_) => ExportOptionsDialog(contextData: exportContext),
        );
        break;
      case 'print':
        await _handlePrint(context);
        break;
      case 'csv':
        _handleCsv(context);
        break;
    }
  }

  Future<void> _handlePrint(BuildContext context) async {
    // Show loading dialog and capture its context
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Druckdaten werden aufbereitet...'),
            ],
          ),
        );
      },
    );

    try {
      final exporter = PdfExporter(template: PdfTemplateRegistry.simple);
      final pdfBytes = await exporter.exportList(
        controller,
        title: config.title,
      );

      // Close loading dialog using its own context
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${config.title} Export',
      );
    } catch (e) {
      // Ensure dialog is closed and show error
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Drucken: $e')),
        );
      }
    }
  }

  Future<void> _handleCsv(BuildContext context) async {
    try {
      final table = controller.toExportDataTable(title: config.title);
      final exporter = CsvExporter();
      final file = await exporter.export(table);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV erstellt: ${file.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim CSV-Export: $e')));
      }
    }
  }
}
