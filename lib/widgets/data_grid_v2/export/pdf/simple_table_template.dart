import 'package:flutter/services.dart';
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
  PdfTemplateCategory get category => PdfTemplateCategory.generic;

  @override
  List<String>? get supportedEntityTypes => null;

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
        build: (pwContext) => _buildBlocks(dataTable, baseFont),
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

    final metaStyle = pw.TextStyle(font: font, fontSize: 8);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (context.title.isNotEmpty) pw.Text(context.title, style: titleStyle),
        if (context.filterDescription != null)
          pw.Text('Filter: ${context.filterDescription}', style: metaStyle),
        if (context.sortDescription != null)
          pw.Text('Sortierung: ${context.sortDescription}', style: metaStyle),
        pw.SizedBox(height: 12),
        pw.Divider(height: 1, thickness: 0.5, color: PdfColors.black),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// Builds individual data blocks per row instead of a wide table.
  List<pw.Widget> _buildBlocks(ExportDataTable dataTable, pw.Font font) {
    final labelStyle = pw.TextStyle(
      font: font,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    final valueStyle = pw.TextStyle(font: font, fontSize: 10);

    final blocks = <pw.Widget>[];

    for (var rowIndex = 0; rowIndex < dataTable.rows.length; rowIndex++) {
      final isLastRow = rowIndex == dataTable.rows.length - 1;
      final row = dataTable.rows[rowIndex];

      blocks.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              for (
                var colIndex = 0;
                colIndex < dataTable.headers.length;
                colIndex++
              )
                if (row[colIndex].isNotEmpty)
                  pw.SizedBox(
                    width: 160,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(dataTable.headers[colIndex], style: labelStyle),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          row[colIndex],
                          style: valueStyle,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );

      if (!isLastRow) {
        blocks.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(thickness: 0.5, color: PdfColors.black),
          ),
        );
      }
    }

    return blocks;
  }

  /// Builds the page footer with timestamp and page numbers.
  pw.Widget _buildFooter(
    PdfExportContext context,
    pw.Context pwContext,
    pw.Font font,
  ) {
    final footerStyle = pw.TextStyle(font: font, fontSize: 8);

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

  /// Loads Roboto Regular from the bundled local asset.
  /// Supports full Latin character set including € and German umlauts.
  Future<pw.Font> _loadFont() async {
    final fontData = await rootBundle.load('lib/assets/fonts/Roboto-Regular.ttf');
    return pw.Font.ttf(fontData);
  }
}
