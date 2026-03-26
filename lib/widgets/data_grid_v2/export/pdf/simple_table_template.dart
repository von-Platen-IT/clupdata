import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../export_data_table.dart';
import 'pdf_export_context.dart';
import 'pdf_template.dart';

/// Default PDF template that generates a clean, paginated table.
///
/// This template provides a professional but minimal layout suitable
/// for general data exports. It includes:
///
/// - Clean table with headers
/// - Alternating row colors for readability
/// - Automatic pagination for long tables
/// - Page numbers and export timestamp in footer
/// - Optional title and filter/sort descriptions
///
/// This is the fallback template when no domain-specific template
/// is selected or registered.
class SimpleTableTemplate implements PdfTemplate {
  @override
  String get displayName => 'Einfache Tabelle';

  @override
  bool get supportsDetailView => true;

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    final pdf = pw.Document();

    // Load fonts for German umlaut support
    final baseFont = await _loadFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        header: (format) => _buildHeader(context, baseFont),
        footer: (pwContext) => _buildFooter(context, pwContext, baseFont),
        build: (pwContext) => [_buildTable(dataTable, baseFont)],
      ),
    );

    return pdf;
  }

  /// Builds the page header with title and metadata.
  pw.Widget _buildHeader(PdfExportContext context, pw.Font font) {
    final titleStyle = pw.TextStyle(
      font: font,
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );

    final metaStyle = pw.TextStyle(
      font: font,
      fontSize: 8,
      color: PdfColors.grey600,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (context.title.isNotEmpty) pw.Text(context.title, style: titleStyle),
        if (context.filterDescription != null)
          pw.Text('Filter: ${context.filterDescription}', style: metaStyle),
        if (context.sortDescription != null)
          pw.Text('Sortierung: ${context.sortDescription}', style: metaStyle),
        pw.SizedBox(height: 12),
        pw.Divider(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// Builds the data table with alternating row colors.
  pw.Widget _buildTable(ExportDataTable dataTable, pw.Font font) {
    final headerStyle = pw.TextStyle(
      font: font,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );

    final cellStyle = pw.TextStyle(font: font, fontSize: 9);

    return pw.TableHelper.fromTextArray(
      headers: dataTable.headers,
      data: dataTable.rows,
      headerStyle: headerStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      headerHeight: 28,
      cellHeight: 22,
      cellStyle: cellStyle,
      cellAlignments: _buildCellAlignments(dataTable.columnCount),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: null,
    );
  }

  /// Builds the page footer with timestamp and page numbers.
  pw.Widget _buildFooter(
    PdfExportContext context,
    pw.Context pwContext,
    pw.Font font,
  ) {
    final footerStyle = pw.TextStyle(
      font: font,
      fontSize: 8,
      color: PdfColors.grey500,
    );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Exportiert: ${context.formattedTimestamp}',
          style: footerStyle,
        ),
        pw.Text(
          'Seite ${pwContext.pageNumber} von ${pwContext.pagesCount}',
          style: footerStyle,
        ),
      ],
    );
  }

  /// Determines text alignment for each column based on content.
  Map<int, pw.Alignment> _buildCellAlignments(int columnCount) {
    final alignments = <int, pw.Alignment>{};
    // By default, all columns are left-aligned
    // Subclasses could override this for numeric columns
    for (var i = 0; i < columnCount; i++) {
      alignments[i] = pw.Alignment.centerLeft;
    }
    return alignments;
  }

  /// Loads a font that supports German umlauts.
  ///
  /// Uses Helvetica as base font which is included in the pdf package.
  Future<pw.Font> _loadFont() async {
    // The pdf package includes standard fonts with Unicode support
    return pw.Font.helvetica();
  }
}
