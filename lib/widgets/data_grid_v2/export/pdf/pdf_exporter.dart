import 'dart:typed_data';

import '../../data_grid_controller.dart';
import '../export_data_table.dart';
import 'pdf_export_context.dart';
import 'pdf_template.dart';
import 'simple_table_template.dart';

/// Data container for PDF export preparation.
///
/// Contains all necessary data and context to generate a PDF,
/// allowing template selection to happen before PDF generation.
class PdfExportData {
  /// The prepared data table with formatted values.
  final ExportDataTable dataTable;

  /// The export context with metadata.
  final PdfExportContext context;

  /// Whether this is a detail view export.
  final bool isDetailView;

  /// Optional entity type for template filtering.
  final String? entityType;

  /// The detected entity type from entity name (e.g., 'rechnung').
  final String? detectedEntityType;

  /// Creates [PdfExportData] with all export parameters.
  const PdfExportData({
    required this.dataTable,
    required this.context,
    required this.isDetailView,
    this.entityType,
    this.detectedEntityType,
  });

  /// Returns the effective entity type for template filtering.
  ///
  /// Uses [detectedEntityType] if available, otherwise [entityType].
  String? get effectiveEntityType => detectedEntityType ?? entityType;
}

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

  /// Prepares export data without generating the PDF.
  ///
  /// This allows template selection to happen in a preview dialog
  /// before the actual PDF is generated.
  ///
  /// [controller] provides the data source.
  /// [title] appears in the PDF header and context metadata.
  /// [entityName] optionally identifies the entity type (e.g., "Mitglied").
  /// [visibleOnly] if true, only filtered/sorted items are exported.
  ///
  /// Returns [PdfExportData] containing all data needed for PDF generation.
  PdfExportData prepareListExport(
    DataGridController<dynamic> controller, {
    required String title,
    String? entityName,
    bool visibleOnly = true,
  }) {
    final dataTable = controller.toExportDataTable(
      title: title,
      visibleOnly: visibleOnly,
    );

    return PdfExportData(
      dataTable: dataTable,
      context: PdfExportContext(
        title: title,
        exportTimestamp: DateTime.now(),
        activeFilters: controller.activeFilters,
        activeSorts: controller.sortConfigs,
        isDetailView: false,
        entityName: entityName,
      ),
      isDetailView: false,
      entityType: entityName,
      detectedEntityType: _detectEntityType(entityName),
    );
  }

  /// Prepares detail export data for a single item.
  ///
  /// [controller] provides column configuration for formatting.
  /// [item] is the single entity to export.
  /// [title] appears in the PDF header.
  /// [entityName] identifies the entity type for the context.
  PdfExportData prepareDetailExport(
    DataGridController<dynamic> controller,
    dynamic item, {
    required String title,
    String? entityName,
  }) {
    final dataTable = controller.toExportDataTableSingleItem(
      item,
      title: title,
    );

    return PdfExportData(
      dataTable: dataTable,
      context: PdfExportContext(
        title: title,
        exportTimestamp: DateTime.now(),
        isDetailView: true,
        entityName: entityName,
      ),
      isDetailView: true,
      entityType: entityName,
      detectedEntityType: _detectEntityType(entityName),
    );
  }

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
    final exportData = prepareListExport(
      controller,
      title: title,
      entityName: entityName,
      visibleOnly: true,
    );

    final document = await _template.generate(
      exportData.dataTable,
      exportData.context,
    );
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
    final exportData = prepareListExport(
      controller,
      title: title,
      entityName: entityName,
      visibleOnly: false,
    );

    final document = await _template.generate(
      exportData.dataTable,
      exportData.context,
    );
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
    final exportData = prepareDetailExport(
      controller,
      item,
      title: title,
      entityName: entityName,
    );

    final document = await _template.generate(
      exportData.dataTable,
      exportData.context,
    );
    return document.save();
  }

  /// Generates a PDF from prepared export data.
  ///
  /// This method is useful when the template is selected after
  /// the export data has been prepared (e.g., in a preview dialog).
  static Future<Uint8List> generateFromData(
    PdfExportData exportData,
    PdfTemplate template,
  ) async {
    final document = await template.generate(
      exportData.dataTable,
      exportData.context,
    );
    return document.save();
  }

  /// Detects entity type from entity name for template filtering.
  String? _detectEntityType(String? entityName) {
    if (entityName == null) return null;

    final lower = entityName.toLowerCase();

    if (lower.contains('rechnung')) return 'rechnung';
    if (lower.contains('mitglied')) return 'mitglied';
    if (lower.contains('beitrag')) return 'beitrag';
    if (lower.contains('leistung')) return 'leistung';
    if (lower.contains('ware')) return 'ware';

    return null;
  }
}
