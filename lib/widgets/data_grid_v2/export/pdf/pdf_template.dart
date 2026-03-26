import 'package:pdf/widgets.dart' as pw;

import '../export_data_table.dart';
import 'pdf_export_context.dart';

/// Interface for PDF layout templates.
///
/// Implementations define how [ExportDataTable] data is rendered into
/// a PDF document. The template system supports two modes:
///
/// 1. **Simple Mode**: Generic table layouts without decoration
///    (e.g., [SimpleTableTemplate])
///
/// 2. **Template Mode**: Domain-specific layouts with logos, headers,
///    footers, and custom formatting (e.g., invoice layouts)
///
/// Templates are registered via [PdfTemplateRegistry] and selected
/// by the user or application logic at export time.
///
/// Example implementation:
/// ```dart
/// class InvoicePdfTemplate implements PdfTemplate {
///   @override
///   String get displayName => 'Rechnungs-Layout';
///
///   @override
///   bool get supportsDetailView => true;
///
///   @override
///   Future<pw.Document> generate(
///     ExportDataTable dataTable,
///     PdfExportContext context,
///   ) async {
///     final pdf = pw.Document();
///     // ... build PDF structure
///     return pdf;
///   }
/// }
/// ```
abstract class PdfTemplate {
  /// The display name shown in template selection UIs.
  String get displayName;

  /// Whether this template supports detail view (single item) exports.
  ///
  /// Some templates like invoice layouts only make sense for single
  /// items and should return `true`. Generic list templates should
  /// return `true` as well since they can render single-row tables.
  ///
  /// If `false`, the template will be hidden when exporting from
  /// a detail dialog context.
  bool get supportsDetailView;

  /// Generates a PDF document from the given data and context.
  ///
  /// [dataTable] contains the pre-formatted tabular data extracted
  /// from [DataGridController] via [DataGridExportAdapter].
  ///
  /// [context] provides metadata like title, timestamp, filters,
  /// and whether this is a detail view export.
  ///
  /// Returns a [pw.Document] that can be saved, printed, or previewed.
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  );
}
