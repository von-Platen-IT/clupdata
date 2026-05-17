import 'dart:typed_data';

import '../../../../core/models/entity_type_info.dart';
import '../../../../core/providers/export_context_provider.dart';
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

/// Exports cached DataGrid data to PDF using a configurable template.
///
/// The exporter operates strictly on `ExportContextData` and `ExportDataTable`
/// snapshots, remaining completely decoupled from UI components or PlutoGrid.
///
/// Example usage:
/// ```dart
/// final exporter = PdfExporter(template: SimpleTableTemplate());
/// final pdfBytes = await exporter.export(exportContextData);
/// await File('export.pdf').writeAsBytes(pdfBytes);
/// ```
class PdfExporter {
  final PdfTemplate _template;

  /// Creates a [PdfExporter] with the given [template].
  ///
  /// If no template is provided, [SimpleTableTemplate] is used as default.
  PdfExporter({PdfTemplate? template})
    : _template = template ?? SimpleTableTemplate();

  /// Prepares PDF export data from a generic [ExportContextData] snapshot.
  ///
  /// Maps the generic OOP export snapshot into PDF-specific metadata
  /// so it can be previewed or rendered. If [useFullTable] is true and
  /// the context has a full dataset, it uses [fullDataTable] instead of [dataTable].
  PdfExportData prepareExport(
    ExportContextData contextData, {
    bool useFullTable = false,
  }) {
    final table = (useFullTable && contextData.fullDataTable != null)
        ? contextData.fullDataTable!
        : contextData.dataTable;

    final pdfContext = PdfExportContext(
      title: contextData.title,
      exportTimestamp: DateTime.now(),
      activeFilters: contextData.activeFilters,
      activeSorts: contextData.activeSorts,
      isDetailView: contextData.isDetail,
      entityName: contextData.entityType,
    );

    return PdfExportData(
      dataTable: table,
      context: pdfContext,
      isDetailView: contextData.isDetail,
      entityType: contextData.entityType,
      detectedEntityType: _detectEntityType(contextData.entityType),
    );
  }

  /// Exports the given snapshot directly as a PDF.
  Future<Uint8List> export(
    ExportContextData contextData, {
    bool useFullTable = false,
  }) async {
    final exportData = prepareExport(contextData, useFullTable: useFullTable);
    return generateFromData(exportData, _template);
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
  /// Delegates to the centralized [EntityTypeInfo] enum.
  String? _detectEntityType(String? entityName) {
    return EntityTypeInfo.detect(entityName);
  }
}
