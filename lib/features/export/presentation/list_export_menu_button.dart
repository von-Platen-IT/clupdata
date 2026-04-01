import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/export/csv_exporter.dart';
// PdfExportData is defined in pdf_exporter.dart (already imported below)
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_preview_dialog.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';
import '../domain/export_config.dart';
import 'export_options_dialog.dart';

/// A button that provides export functionality for list views (DataGrid).
///
/// Provides options to export to PDF, print, or CSV.
/// Reads the data purely from the [exportCacheProvider] snapshot, completely
/// decoupled from DataGridController or PlutoGrid.
class ListExportMenuButton<T> extends ConsumerWidget {
  /// Configuration for the export (title, entity type).
  final ExportConfig config;

  const ListExportMenuButton({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onSelected: (value) => _handleSelection(context, ref, value),
    );
  }

  Future<void> _handleSelection(BuildContext context, WidgetRef ref, String value) async {
    final snapshotGenerator = ref.read(exportCacheProvider);

    if (snapshotGenerator == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler: Export-Generator nicht gefunden.')),
        );
      }
      return;
    }

    final exportContext = snapshotGenerator();

    if (exportContext == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Die Tabelle ist noch nicht bereit für den Export.')),
        );
      }
      return;
    }

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
      case 'csv':
        _handleCsv(context, exportContext);
        break;
    }
  }

  Future<void> _handlePrint(BuildContext context, ExportContextData exportContext) async {
    try {
      final exporter = PdfExporter(template: PdfTemplateRegistry.simple);
      
      // Für schnellen Druck verwenden wir direkt die sichtbare Tabelle.
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

  Future<void> _handleCsv(BuildContext context, ExportContextData exportContext) async {
    try {
      final exporter = CsvExporter();
      // CSV exportiert die aktuell sichtbare Tabelle
      final file = await exporter.export(exportContext.dataTable);

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
