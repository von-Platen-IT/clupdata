import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../export_data_table.dart';
import 'pdf_export_context.dart';
import 'pdf_template.dart';

/// Default PDF template that generates a clean, compact, paginated table.
///
/// This template provides a professional layout optimized for
/// data-dense list exports on DIN A4. It includes:
///
/// - Compact table with auto-sized columns
/// - Alternating row colors for readability
/// - Small but legible font sizes (8pt header, 7.5pt data)
/// - Minimal margins and padding for maximum content density
/// - Automatic pagination for long tables
/// - Page numbers and export timestamp in footer
///
/// For detail exports (single item), a key-value layout is used.
class SimpleTableTemplate implements PdfTemplate {
  @override
  String get displayName => 'Einfache Tabelle';

  @override
  bool get supportsDetailView => true;

  @override
  PdfTemplateCategory get category => PdfTemplateCategory.generic;

  @override
  List<String>? get supportedEntityTypes => null;

  /// Font sizes for compact layout.
  static const double _headerFontSize = 8;
  static const double _dataFontSize = 7.5;
  static const double _titleFontSize = 12;
  static const double _metaFontSize = 7;

  /// Row heights for consistent spacing.
  static const double _headerRowHeight = 18;
  static const double _dataRowHeight = 14;

  /// Page margins — reduced from 48 to 32 for more content area.
  static const double _pageMargin = 32;

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    final pdf = pw.Document();
    final baseFont = await _loadFont();
    final boldFont = await _loadBoldFont();

    // Calculate column widths based on content.
    final columnWidths = _calculateColumnWidths(dataTable);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        header: (format) => _buildHeader(context, baseFont, boldFont),
        footer: (pwContext) =>
            _buildFooter(context, pwContext, baseFont, dataTable.rowCount),
        build: (pwContext) => [
          if (context.isDetailView)
            _buildDetailTable(dataTable, baseFont, boldFont)
          else
            _buildListTable(dataTable, baseFont, boldFont, columnWidths),
        ],
      ),
    );

    return pdf;
  }

  /// Builds a compact key-value table for detail exports (single item).
  pw.Widget _buildDetailTable(
    ExportDataTable dataTable,
    pw.Font normalFont,
    pw.Font boldFont,
  ) {
    final labelStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );
    final valueStyle = pw.TextStyle(font: normalFont, fontSize: 8);

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

  /// Builds a compact header with title and optional filter/sort info.
  pw.Widget _buildHeader(
    PdfExportContext context,
    pw.Font normalFont,
    pw.Font boldFont,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              context.title,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: _titleFontSize,
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
        if (context.filterDescription != null ||
            context.sortDescription != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
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
          ),
        pw.SizedBox(height: 4),
        pw.Divider(height: 0.5, thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 4),
      ],
    );
  }

  /// Builds the main compact data table for list exports.
  pw.Widget _buildListTable(
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

  /// Builds the page footer with row count, timestamp and page numbers.
  pw.Widget _buildFooter(
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
            '$rowCount Datensätze | Exportiert: ${context.formattedTimestamp}',
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

  /// Calculates optimal column widths based on header length.
  List<pw.FlexColumnWidth> _calculateColumnWidths(ExportDataTable dataTable) {
    final columnCount = dataTable.columnCount;
    if (columnCount == 0) return [];

    final widths = <pw.FlexColumnWidth>[];
    final maxHeaderLength = dataTable.headers
        .map((h) => h.length)
        .reduce((a, b) => a > b ? a : b);

    for (final header in dataTable.headers) {
      final ratio = header.length / maxHeaderLength;
      // Minimum width factor to prevent very narrow columns.
      final widthFactor = 0.5 + (ratio * 0.5);
      widths.add(pw.FlexColumnWidth(widthFactor));
    }

    return widths;
  }

  /// Checks if a value is a formatted number or currency amount.
  bool _isNumeric(String value) {
    if (value.isEmpty) return false;
    final hasDecimalOrCurrency = RegExp(r'[,€$£%]').hasMatch(value);
    if (!hasDecimalOrCurrency) return false;
    final clean = value
        .replaceAll(RegExp(r'[.€$£%\s]'), '')
        .replaceAll(',', '.');
    return double.tryParse(clean) != null;
  }

  /// Loads Roboto Regular from the bundled local asset.
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
