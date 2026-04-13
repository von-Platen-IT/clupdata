import '../../../../core/database/database.dart';
import '../../domain/batch_export_summary.dart';
import '../summary_generator.dart';

/// Generates summary data for Rechnungen (invoices) batch exports.
class RechnungenSummaryGenerator implements SummaryGenerator {
  final AppDatabase _db;

  RechnungenSummaryGenerator(this._db);

  @override
  String get entityType => 'rechnung';

  @override
  Future<BatchExportSummary> generateSummary({
    required List<int> exportedItemIds,
    required String entityDisplayName,
    required DateTime? dateFrom,
    required DateTime? dateTo,
  }) async {
    if (exportedItemIds.isEmpty) {
      return BatchExportSummary(
        entityType: entityType,
        entityDisplayName: entityDisplayName,
        exportedAt: DateTime.now(),
        totalCount: 0,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    }

    // Fetch all exported invoices for aggregation
    final rechnungen = await (_db.select(
      _db.rechnungen,
    )..where((r) => r.id.isIn(exportedItemIds))).get();

    // Calculate totals
    double totalNetto = 0;
    double totalBrutto = 0;
    double totalMwst = 0;
    final statusCounts = <String, int>{};
    final statusAmounts = <String, double>{};

    for (final r in rechnungen) {
      totalNetto += r.betragNetto;
      totalBrutto += r.betragBrutto;
      totalMwst += r.betragMwst;

      statusCounts[r.status] = (statusCounts[r.status] ?? 0) + 1;
      statusAmounts[r.status] = (statusAmounts[r.status] ?? 0) + r.betragBrutto;
    }

    final totalCount = rechnungen.length;

    // Build sections
    final sections = <SummarySection>[
      // Totals section
      SummarySection(
        title: 'Beträge',
        rows: [
          SummaryRow.withCurrency(label: 'Gesamt netto', amount: totalNetto),
          SummaryRow.withCurrency(label: 'Gesamt MwSt', amount: totalMwst),
          SummaryRow.withCurrency(label: 'Gesamt brutto', amount: totalBrutto),
        ],
        type: SummarySectionType.amountTable,
      ),
      // Status distribution
      SummarySection(
        title: 'Status',
        rows: statusCounts.entries.map((e) {
          final status = e.key;
          final count = e.value;
          final amount = statusAmounts[status] ?? 0;
          return SummaryRow(
            label: _statusLabel(status),
            value: '$count (${_formatCurrency(amount)})',
            percentage: totalCount > 0 ? count / totalCount : 0,
            amount: amount,
          );
        }).toList(),
        type: SummarySectionType.amountTable,
      ),
    ];

    return BatchExportSummary(
      entityType: entityType,
      entityDisplayName: entityDisplayName,
      exportedAt: DateTime.now(),
      totalCount: totalCount,
      dateFrom: dateFrom,
      dateTo: dateTo,
      sections: sections,
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'offen':
        return 'Offen';
      case 'bezahlt':
        return 'Bezahlt';
      case 'storniert':
        return 'Storniert';
      default:
        return status;
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
}
