/// PDF Export library for VpitDataGrid.
///
/// This library provides a template-based PDF export system for
/// DataGrid data. It supports both simple table layouts and
/// domain-specific custom templates.
///
/// ## Usage
///
/// ### Basic Export
/// ```dart
/// final exporter = PdfExporter();
/// final pdfBytes = await exporter.exportList(
///   controller,
///   title: 'Mitgliederliste',
/// );
/// ```
///
/// ### Custom Template
/// ```dart
/// class MyTemplate implements PdfTemplate {
///   @override
///   Future<pw.Document> generate(
///     ExportDataTable data,
///     PdfExportContext context,
///   ) async {
///     // ... build PDF
///   }
/// }
///
/// PdfTemplateRegistry.register('my_template', MyTemplate());
/// ```
///
/// ### UI Integration
/// ```dart
/// PdfExportMenuItem<MemberRowData>(
///   controller: memberController,
///   title: 'Mitglieder',
/// )
/// ```
///
/// ## Architecture
///
/// The PDF export follows the template pattern:
/// - [PdfExporter] orchestrates the export process
/// - [PdfTemplate] defines the layout contract
/// - [PdfTemplateRegistry] manages available templates
/// - [PdfExportContext] provides metadata for templates
/// - [SimpleTableTemplate] is the default generic template
///
/// See README.md Section "PDF Export & Templates" for detailed documentation.
library;

export 'pdf_export_context.dart';
export 'pdf_exporter.dart';
export 'pdf_export_menu_item.dart';
export 'pdf_preview_dialog.dart';
export 'pdf_template.dart';
export 'pdf_template_registry.dart';
export 'simple_table_template.dart';

// Re-export templates for convenience
export '../templates/pdf_templates.dart';
