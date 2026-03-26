import 'package:flutter/material.dart';

import '../../data_grid_controller.dart';
import 'pdf_exporter.dart';
import 'pdf_preview_dialog.dart';
import 'pdf_template.dart';
import 'pdf_template_registry.dart';

/// Menu item widget for PDF export functionality.
///
/// Handles the complete export flow:
/// 1. Extract data from controller
/// 2. Generate PDF with selected template
/// 3. Show preview dialog
///
/// Can be used in DropdownButton, MenuBar, or PopupMenuButton.
///
/// Example in a MenuBar:
/// ```dart
/// SubmenuButton(
///   menuChildren: [
///     PdfExportMenuItem<MemberRowData>(
///       controller: memberController,
///       title: 'Mitgliederliste',
///       entityName: 'Mitglied',
///     ),
///   ],
///   child: Text('Exportieren'),
/// )
/// ```
class PdfExportMenuItem<T> extends StatelessWidget {
  /// The controller providing data and column configuration.
  final DataGridController<T> controller;

  /// The export title shown in PDF header and dialogs.
  final String title;

  /// Optional entity name for context (e.g., "Mitglied", "Rechnung").
  final String? entityName;

  /// Optional specific template to use. If null, uses [PdfTemplateRegistry.simple].
  final PdfTemplate? template;

  /// Optional callback when export completes successfully.
  final VoidCallback? onExported;

  /// Creates a [PdfExportMenuItem] with the given configuration.
  const PdfExportMenuItem({
    super.key,
    required this.controller,
    required this.title,
    this.entityName,
    this.template,
    this.onExported,
  });

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: const Icon(Icons.picture_as_pdf_outlined),
      onPressed: () => _handleExport(context),
      child: const Text('PDF erstellen...'),
    );
  }

  /// Handles the export flow: generate PDF and show preview.
  Future<void> _handleExport(BuildContext context) async {
    try {
      // Show loading indicator
      _showLoadingDialog(context);

      // Generate PDF
      final exporter = PdfExporter(
        template: template ?? PdfTemplateRegistry.simple,
      );
      final pdfBytes = await exporter.exportList(
        controller,
        title: title,
        entityName: entityName,
      );

      // Hide loading
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      // Show preview
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => PdfPreviewDialog(pdfData: pdfBytes, title: title),
        );
      }

      onExported?.call();
    } catch (e) {
      // Hide loading if still showing
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  /// Shows a loading indicator while generating PDF.
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('PDF wird erstellt...'),
          ],
        ),
      ),
    );
  }

  /// Shows an error dialog if export fails.
  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Export fehlgeschlagen'),
        content: Text(
          'Beim Erstellen des PDF ist ein Fehler aufgetreten:\n$error',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Extension for detail view PDF export.
///
/// Similar to [PdfExportMenuItem] but exports a single item
/// in detail view format.
class PdfExportDetailMenuItem<T> extends StatelessWidget {
  /// The controller providing column configuration.
  final DataGridController<T> controller;

  /// The single item to export.
  final T item;

  /// The export title.
  final String title;

  /// Optional entity name.
  final String? entityName;

  /// Optional template. Defaults to simple template.
  final PdfTemplate? template;

  /// Creates a [PdfExportDetailMenuItem].
  const PdfExportDetailMenuItem({
    super.key,
    required this.controller,
    required this.item,
    required this.title,
    this.entityName,
    this.template,
  });

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: const Icon(Icons.picture_as_pdf_outlined),
      onPressed: () => _handleExport(context),
      child: const Text('Als PDF exportieren...'),
    );
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
      _showLoadingDialog(context);

      final exporter = PdfExporter(
        template: template ?? PdfTemplateRegistry.simple,
      );
      final pdfBytes = await exporter.exportDetail(
        controller,
        item,
        title: title,
        entityName: entityName,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => PdfPreviewDialog(pdfData: pdfBytes, title: title),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('PDF wird erstellt...'),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Export fehlgeschlagen'),
        content: Text(
          'Beim Erstellen des PDF ist ein Fehler aufgetreten:\n$error',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
