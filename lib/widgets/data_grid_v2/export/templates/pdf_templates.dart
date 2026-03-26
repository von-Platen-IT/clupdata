/// Domain-specific PDF templates library.
///
/// This library contains custom PDF templates for specific use cases
/// beyond the generic [SimpleTableTemplate].
///
/// ## Available Templates
///
/// - [InvoicePdfTemplate] - Professional invoice layout with letterhead,
///   positions table, and totals section.
/// - [CompactTableTemplate] - Compact table layout for maximum data density.
///
/// ## Creating Custom Templates
///
/// To create a custom template, implement the [PdfTemplate] interface:
///
/// ```dart
/// class MyCustomTemplate implements PdfTemplate {
///   @override
///   String get displayName => 'My Custom Layout';
///
///   @override
///   bool get supportsDetailView => true;
///
///   @override
///   PdfTemplateCategory get category => PdfTemplateCategory.generic;
///
///   @override
///   Future<pw.Document> generate(
///     ExportDataTable dataTable,
///     PdfExportContext context,
///   ) async {
///     final pdf = pw.Document();
///     // ... build your layout
///     return pdf;
///   }
/// }
/// ```
///
/// Then register it:
/// ```dart
/// PdfTemplateRegistry.register('my_template', MyCustomTemplate());
/// ```
library;

export 'invoice_pdf_template.dart';
export '../pdf/compact_table_template.dart';
