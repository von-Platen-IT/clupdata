import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../export_data_table.dart';
import 'pdf_export_context.dart';
import 'pdf_template.dart';

/// Compact PDF template for maximum data density on DIN A4 pages.
///
/// This template provides:
/// - Smaller font sizes for more columns per page
/// - Minimal padding and margins
/// - Optimized for lists with many columns
///
/// Best used when:
/// - Many columns need to be displayed
/// - Space efficiency is more important than readability
/// - Printing detailed reports with lots of data
class CompactTableTemplate implements PdfTemplate {
  @override
  String get displayName => 'Kompakte Tabelle';

  @override
  bool get supportsDetailView => true;

  @override
  PdfTemplateCategory get category => PdfTemplateCategory.list;

  @override
  List<String>? get supportedEntityTypes => null;

  /// Font sizes for compact layout
  static const double _headerFontSize = 8;
  static const double _dataFontSize = 7;
  static const double _metaFontSize = 6;

  /// Row heights
  static const double _headerRowHeight = 18;
  static const double _dataRowHeight = 14;

  /// Page margins - smaller for more content
  static const double _pageMargin = 32;

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    final pdf = pw.Document();
    final baseFont = await _loadFont();
    final boldFont = await _loadBoldFont();

    // Calculate column widths based on content
    final columnWidths = _calculateColumnWidths(dataTable);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        header: (format) => _buildCompactHeader(context, baseFont, boldFont),
        footer: (pwContext) => _buildCompactFooter(
          context,
          pwContext,
          baseFont,
          dataTable.rowCount,
        ),
        build: (pwContext) => [
          if (context.isDetailView)
            _buildDetailTable(dataTable, baseFont, boldFont)
          else
            _buildCompactTable(dataTable, baseFont, boldFont, columnWidths),
        ],
      ),
    );

    return pdf;
  }

  /// Builds a clean two-column key-value table for detail exports.
  ///
  /// Field names are displayed in the left column (bold) and values in the
  /// right column. The "Feld"/"Wert" headers are omitted for clarity.
  pw.Widget _buildDetailTable(
    ExportDataTable dataTable,
    pw.Font normalFont,
    pw.Font boldFont,
  ) {
    final labelStyle = pw.TextStyle(
      font: boldFont,
      fontSize: _headerFontSize,
      fontWeight: pw.FontWeight.bold,
    );
    final valueStyle = pw.TextStyle(font: normalFont, fontSize: _dataFontSize);

    return pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
      ),
      children: [
        ...dataTable.rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;
          final isEven = rowIndex % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: pw.Text(row.isNotEmpty ? row[0] : '', style: labelStyle),
              ),
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: pw.Text(row.length > 1 ? row[1] : '', style: valueStyle),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Builds a compact header with minimal height.
  pw.Widget _buildCompactHeader(
    PdfExportContext context,
    pw.Font normalFont,
    pw.Font boldFont,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Title line
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              context.title,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              context.formattedDate,
              style: pw.TextStyle(
                font: normalFont,
                fontSize: _metaFontSize,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        // Filter/Sort info in compact form
        if (context.filterDescription != null ||
            context.sortDescription != null)
          pw.Text(
            [
              if (context.filterDescription != null)
                'Filter: ${context.filterDescription}',
              if (context.sortDescription != null)
                'Sort: ${context.sortDescription}',
            ].join(' | '),
            style: pw.TextStyle(
              font: normalFont,
              fontSize: _metaFontSize,
              color: PdfColors.grey600,
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Divider(height: 0.5, thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 4),
      ],
    );
  }

  /// Builds the main compact table.
  pw.Widget _buildCompactTable(
    ExportDataTable dataTable,
    pw.Font normalFont,
    pw.Font boldFont,
    List<pw.FlexColumnWidth> columnWidths,
  ) {
    return pw.Table(
      columnWidths: columnWidths.isNotEmpty
          ? columnWidths.asMap().map((i, w) => MapEntry(i, w))
          : null,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
      ),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
            ),
          ),
          children: dataTable.headers.map((header) {
            return pw.Container(
              height: _headerRowHeight,
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              child: pw.Text(
                header,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: _headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
                overflow: pw.TextOverflow.clip,
                maxLines: 1,
              ),
            );
          }).toList(),
        ),
        // Data rows with alternating background
        ...dataTable.rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;
          final isEven = rowIndex % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : PdfColors.grey50,
            ),
            children: row.asMap().entries.map((cellEntry) {
              final cellValue = cellEntry.value;
              final isNumeric = _isNumeric(cellValue);

              return pw.Container(
                height: _dataRowHeight,
                alignment: isNumeric
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                child: pw.Text(
                  cellValue,
                  style: pw.TextStyle(
                    font: normalFont,
                    fontSize: _dataFontSize,
                    color: PdfColors.black,
                  ),
                  overflow: pw.TextOverflow.clip,
                  maxLines: 1,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  /// Builds a compact footer with page numbers.
  pw.Widget _buildCompactFooter(
    PdfExportContext context,
    pw.Context pwContext,
    pw.Font font,
    int rowCount,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$rowCount Datensätze',
            style: pw.TextStyle(
              font: font,
              fontSize: _metaFontSize,
              color: PdfColors.grey500,
            ),
          ),
          pw.Text(
            'Seite ${pwContext.pageNumber}/${pwContext.pagesCount}',
            style: pw.TextStyle(
              font: font,
              fontSize: _metaFontSize,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  /// Calculates optimal column widths based on content.
  List<pw.FlexColumnWidth> _calculateColumnWidths(ExportDataTable dataTable) {
    final columnCount = dataTable.columnCount;
    if (columnCount == 0) return [];

    // Calculate relative widths based on header length
    final widths = <pw.FlexColumnWidth>[];
    final maxHeaderLength = dataTable.headers
        .map((h) => h.length)
        .reduce((a, b) => a > b ? a : b);

    for (final header in dataTable.headers) {
      // Longer headers get proportionally more space
      final ratio = header.length / maxHeaderLength;
      // Minimum width factor to prevent very narrow columns
      final widthFactor = 0.5 + (ratio * 0.5);
      widths.add(pw.FlexColumnWidth(widthFactor));
    }

    return widths;
  }

  /// Checks if a value is a formatted number or currency amount.
  ///
  /// Returns true only for values that contain a decimal separator (,)
  /// or a currency/percent symbol. Pure digit strings like phone numbers
  /// or IDs are treated as text and left-aligned.
  bool _isNumeric(String value) {
    if (value.isEmpty) return false;
    // Must contain a currency symbol or decimal comma to be right-aligned.
    // Plain digit sequences (phone numbers, IDs) return false.
    final hasDecimalOrCurrency = RegExp(r'[,€$£%]').hasMatch(value);
    if (!hasDecimalOrCurrency) return false;
    // Strip formatting and verify it parses as a number.
    final clean = value
        .replaceAll(RegExp(r'[.€$£%\s]'), '')
        .replaceAll(',', '.');
    return double.tryParse(clean) != null;
  }

  /// Loads Roboto Regular from the bundled local asset.
  /// Supports full Latin character set including € and German umlauts.
  Future<pw.Font> _loadFont() async {
    final fontData = await rootBundle.load(
      'lib/assets/fonts/Roboto-Regular.ttf',
    );
    return pw.Font.ttf(fontData);
  }

  /// Loads Roboto Bold from the bundled local asset.
  Future<pw.Font> _loadBoldFont() async {
    final fontData = await rootBundle.load('lib/assets/fonts/Roboto-Bold.ttf');
    return pw.Font.ttf(fontData);
  }
}
