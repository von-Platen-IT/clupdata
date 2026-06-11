import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/export/csv_exporter.dart';
// PdfExportData is defined in pdf_exporter.dart (already imported below)
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_preview_dialog.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';
import '../domain/export_config.dart';

/// A button that provides export functionality for list views (DataGrid).
///
/// Provides options to export to PDF, print, or CSV.
/// If [exportGenerator] is provided, it is used directly (preferred — avoids
/// stale data when multiple VpitDataGrids are mounted via StatefulShellRoute).
/// Otherwise falls back to the global [exportCacheProvider].
class ListExportMenuButton<T> extends ConsumerWidget {
  /// Configuration for the export (title, entity type).
  final ExportConfig config;

  /// Optional local export generator from the parent VpitDataGrid.
  /// When provided, bypasses the global [exportCacheProvider] to avoid
  /// stale data from other mounted screens.
  final ExportGenerator? exportGenerator;

  const ListExportMenuButton({
    super.key,
    required this.config,
    this.exportGenerator,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton.outlined(
      tooltip: 'Exportieren',
      icon: const Icon(Icons.more_vert),
      onPressed: () async {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final overlay =
            Navigator.of(context).overlay!.context.findRenderObject()
                as RenderBox;
        final position = RelativeRect.fromRect(
          Rect.fromPoints(
            renderBox.localToGlobal(Offset.zero, ancestor: overlay),
            renderBox.localToGlobal(
              renderBox.size.bottomRight(Offset.zero),
              ancestor: overlay,
            ),
          ),
          Offset.zero & overlay.size,
        );

        final value = await showMenu<String>(
          context: context,
          position: position,
          items: [
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
        );

        if (value != null && context.mounted) {
          await _handleSelection(context, ref, value);
        }
      },
    );
  }

  Future<void> _handleSelection(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    // Prefer local generator (passed from parent VpitDataGrid) to avoid
    // stale data when multiple screens are mounted via StatefulShellRoute.
    final snapshotGenerator = exportGenerator ?? ref.read(exportCacheProvider);

    if (snapshotGenerator == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler: Export-Generator nicht gefunden.'),
          ),
        );
      }
      return;
    }

    final exportContext = snapshotGenerator();

    if (exportContext == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die Tabelle ist noch nicht bereit für den Export.'),
          ),
        );
      }
      return;
    }

    switch (value) {
      case 'pdf':
        // Always export all columns — no options dialog needed.
        final exporter = PdfExporter();
        final exportData = exporter.prepareExport(
          exportContext,
          useFullTable: true,
        );
        if (context.mounted) {
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

  Future<void> _handlePrint(
    BuildContext context,
    ExportContextData exportContext,
  ) async {
    try {
      final exporter = PdfExporter(template: PdfTemplateRegistry.simple);

      // Always print all columns.
      final pdfBytes = await exporter.export(exportContext, useFullTable: true);

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${exportContext.title} Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Drucken: $e')));
      }
    }
  }

  Future<void> _handleCsv(
    BuildContext context,
    ExportContextData exportContext,
  ) async {
    try {
      // Vorschlag für den Dateinamen
      final sanitizedTitle = exportContext.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final suggestedName = '${sanitizedTitle}_$timestamp.csv';

      // FilePicker-Speicherort-Dialog anzeigen
      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'CSV-Datei speichern',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (filePath == null) {
        // Benutzer hat abgebrochen
        return;
      }

      final exporter = CsvExporter();
      // CSV mit benutzerdefiniertem Pfad exportieren
      final file = await exporter.export(
        exportContext.dataTable,
        filePath: filePath,
      );

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
