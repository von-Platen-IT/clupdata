import 'dart:typed_data';

import '../../data_grid_controller.dart';
import '../export_data_table.dart';
import 'pdf_export_context.dart';
import 'pdf_template.dart';
import 'simple_table_template.dart';

/// Exports DataGrid data to PDF using a configurable template.
///
/// The exporter uses the controller's export methods to convert
/// typed data into a generic [ExportDataTable], then applies a [PdfTemplate]
/// to generate the final PDF document.
///
/// Supports both list exports (all filtered/sorted items) and detail
/// exports (single item from a detail dialog).
///
/// Works with any [DataGridController] type, including [DataGridController<dynamic>]
/// returned by the [activeDataGridControllerProvider].
///
/// Example usage:
/// ```dart
/// final exporter = PdfExporter(template: SimpleTableTemplate());
/// final pdfBytes = await exporter.exportList(
///   controller,
///   title: 'Mitgliederliste',
/// );
/// await File('export.pdf').writeAsBytes(pdfBytes);
/// ```
class PdfExporter {
  final PdfTemplate _template;

  /// Creates a [PdfExporter] with the given [template].
  ///
  /// If no template is provided, [SimpleTableTemplate] is used as default.
  PdfExporter({PdfTemplate? template})
    : _template = template ?? SimpleTableTemplate();

  /// Exports the currently filtered and sorted items as a PDF list.
  ///
  /// [controller] provides the data source. Can be any [DataGridController]
  /// including [DataGridController<dynamic>].
  /// [title] appears in the PDF header and context metadata.
  /// [entityName] optionally identifies the entity type (e.g., "Mitglied").
  ///
  /// Returns the PDF as a byte array suitable for saving or printing.
  Future<Uint8List> exportList(
    DataGridController<dynamic> controller, {
    required String title,
    String? entityName,
  }) async {
    final dataTable = controller.toExportDataTable(title: title, visibleOnly: true);
    final context = PdfExportContext(
      title: title,
      exportTimestamp: DateTime.now(),
      activeFilters: controller.activeFilters,
      activeSorts: controller.sortConfigs,
      isDetailView: false,
      entityName: entityName,
    );

    final document = await _template.generate(dataTable, context);
    return document.save();
  }

  /// Exports all items (ignoring filters) as a PDF list.
  ///
  /// Use this when you want to export the complete dataset regardless
  /// of current filter/sort settings in the UI.
  Future<Uint8List> exportAll(
    DataGridController<dynamic> controller, {
    required String title,
    String? entityName,
  }) async {
    final dataTable = controller.toExportDataTable(title: title, visibleOnly: false);
    final context = PdfExportContext(
      title: title,
      exportTimestamp: DateTime.now(),
      activeFilters: {},
      activeSorts: controller.sortConfigs,
      isDetailView: false,
      entityName: entityName,
    );

    final document = await _template.generate(dataTable, context);
    return document.save();
  }

  /// Exports a single item as a PDF detail view.
  ///
  /// [controller] provides column configuration for formatting.
  /// [item] is the single entity to export.
  /// [title] appears in the PDF header.
  /// [entityName] identifies the entity type for the context.
  ///
  /// This creates a single-row [ExportDataTable] with the item's data
  /// formatted according to the controller's column configurations.
  Future<Uint8List> exportDetail(
    DataGridController<dynamic> controller,
    dynamic item, {
    required String title,
    String? entityName,
  }) async {
    final dataTable = controller.toExportDataTableSingleItem(item, title: title);
    final context = PdfExportContext(
      title: title,
      exportTimestamp: DateTime.now(),
      isDetailView: true,
      entityName: entityName,
    );

    final document = await _template.generate(dataTable, context);
    return document.save();
  }
}
