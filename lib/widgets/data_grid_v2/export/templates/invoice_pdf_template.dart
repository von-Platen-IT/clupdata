import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../export_data_table.dart';
import '../pdf/pdf_export_context.dart';
import '../pdf/pdf_template.dart';

/// PDF template for invoice layouts.
///
/// This template creates a professional invoice document with:
/// - Letterhead with company info (placeholder)
/// - Invoice header (number, date, customer)
/// - Item table with positions
/// - Totals section
/// - Footer with bank details and legal text
///
/// **Note:** This template is designed for detail view exports
/// (single invoice) and will throw if used for list exports.
///
/// ## Expected Data Format
///
/// The [ExportDataTable] should contain label-value pairs where
/// standard fields are recognized:
/// - 'Rechnungsnummer' / 'Invoice Number'
/// - 'Datum' / 'Date'
/// - 'Kunde' / 'Customer'
/// - 'Gesamtbetrag' / 'Total'
///
/// Example registration:
/// ```dart
/// PdfTemplateRegistry.register('invoice', InvoicePdfTemplate(
///   companyName: 'Mein Boxclub',
///   companyAddress: 'Musterstraße 1\n12345 Musterstadt',
/// ));
/// ```
class InvoicePdfTemplate implements PdfTemplate {
  /// Company name shown in letterhead.
  final String companyName;

  /// Company address shown in letterhead (multiline).
  final String companyAddress;

  /// Optional company logo image provider.
  final pw.ImageProvider? logo;

  /// Optional bank account details for footer.
  final String? bankDetails;

  /// Optional legal notice / footer text.
  final String? legalNotice;

  /// Creates an [InvoicePdfTemplate] with company information.
  const InvoicePdfTemplate({
    required this.companyName,
    required this.companyAddress,
    this.logo,
    this.bankDetails,
    this.legalNotice,
  });

  @override
  String get displayName => 'Rechnungs-Layout';

  @override
  bool get supportsDetailView => true;

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    if (!context.isDetailView) {
      throw UnsupportedError(
        'InvoicePdfTemplate is designed for detail view exports only. '
        'Please use SimpleTableTemplate for list exports.',
      );
    }

    final pdf = pw.Document();
    final font = await _loadFont();

    // Convert row data to field map for easier access
    final fields = _buildFieldMap(dataTable);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (pwContext) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildLetterhead(font),
            pw.SizedBox(height: 30),
            _buildInvoiceInfo(fields, font),
            pw.SizedBox(height: 30),
            _buildPositionsTable(dataTable, font),
            pw.SizedBox(height: 20),
            _buildTotals(fields, font),
            pw.Spacer(),
            _buildFooter(font),
          ],
        ),
      ),
    );

    return pdf;
  }

  /// Builds the company letterhead with logo and address.
  pw.Widget _buildLetterhead(pw.Font font) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null)
          pw.Container(width: 80, height: 80, child: pw.Image(logo!)),
        if (logo != null) pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyName,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                companyAddress,
                style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the invoice information section.
  pw.Widget _buildInvoiceInfo(Map<String, String> fields, pw.Font font) {
    final headerStyle = pw.TextStyle(
      font: font,
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final valueStyle = pw.TextStyle(font: font, fontSize: 10);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Rechnungsnummer:', style: headerStyle),
                pw.Text(
                  fields['rechnungsnummer'] ?? fields['Rechnungsnummer'] ?? '-',
                  style: valueStyle,
                ),
                pw.SizedBox(height: 8),
                pw.Text('Datum:', style: headerStyle),
                pw.Text(
                  fields['datum'] ?? fields['Datum'] ?? '-',
                  style: valueStyle,
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Kunde:', style: headerStyle),
                pw.Text(
                  fields['kunde'] ?? fields['Kunde'] ?? '-',
                  style: valueStyle,
                ),
                pw.SizedBox(height: 8),
                pw.Text('Zahlungsziel:', style: headerStyle),
                pw.Text(
                  fields['zahlungsziel'] ?? fields['Zahlungsziel'] ?? '14 Tage',
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the positions table from data rows.
  pw.Widget _buildPositionsTable(ExportDataTable dataTable, pw.Font font) {
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
      border: null,
      cellAlignments: _buildCellAlignments(dataTable.columnCount),
    );
  }

  /// Builds the totals section.
  pw.Widget _buildTotals(Map<String, String> fields, pw.Font font) {
    final labelStyle = pw.TextStyle(font: font, fontSize: 10);
    final valueStyle = pw.TextStyle(
      font: font,
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final totalStyle = pw.TextStyle(
      font: font,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Zwischensumme:', style: labelStyle),
                pw.Text(
                  fields['zwischensumme'] ?? fields['Zwischensumme'] ?? '-',
                  style: valueStyle,
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MwSt:', style: labelStyle),
                pw.Text(
                  fields['mwst'] ?? fields['MwSt'] ?? '-',
                  style: valueStyle,
                ),
              ],
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Gesamtbetrag:', style: totalStyle),
                pw.Text(
                  fields['gesamtbetrag'] ??
                      fields['Gesamtbetrag'] ??
                      fields['total'] ??
                      '-',
                  style: totalStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the footer with bank details and legal notice.
  pw.Widget _buildFooter(pw.Font font) {
    final footerStyle = pw.TextStyle(
      font: font,
      fontSize: 8,
      color: PdfColors.grey600,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        if (bankDetails != null) pw.Text(bankDetails!, style: footerStyle),
        if (bankDetails != null) pw.SizedBox(height: 8),
        if (legalNotice != null) pw.Text(legalNotice!, style: footerStyle),
      ],
    );
  }

  /// Converts data table rows to a field map for easier access.
  Map<String, String> _buildFieldMap(ExportDataTable dataTable) {
    final map = <String, String>{};
    for (final row in dataTable.rows) {
      if (row.length >= 2) {
        final key = row[0].toLowerCase().trim();
        final value = row[1];
        map[key] = value;
        // Also store with original case
        map[row[0]] = value;
      }
    }
    return map;
  }

  /// Determines text alignment for each column.
  Map<int, pw.Alignment> _buildCellAlignments(int columnCount) {
    final alignments = <int, pw.Alignment>{};
    for (var i = 0; i < columnCount; i++) {
      // Right-align last column (typically price/total)
      if (i == columnCount - 1) {
        alignments[i] = pw.Alignment.centerRight;
      } else {
        alignments[i] = pw.Alignment.centerLeft;
      }
    }
    return alignments;
  }

  /// Loads the base font with Unicode support.
  Future<pw.Font> _loadFont() async {
    return pw.Font.helvetica();
  }
}
