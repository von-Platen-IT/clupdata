import '../../../../core/database/database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/batch_export_summary.dart';
import '../summary_generator.dart';

/// Generates summary data for Waren (goods) batch exports.
class WarenSummaryGenerator implements SummaryGenerator {
  final AppDatabase _db;

  WarenSummaryGenerator(this._db);

  @override
  String get entityType => 'ware';

  @override
  Future<BatchExportSummary> generateSummary({
    required List<int> exportedItemIds,
    required String entityDisplayName,
    required DateTime? dateFrom,
    required DateTime? dateTo,
  }) async {
    if (exportedItemIds.isEmpty) {
      return SummaryGenerator.emptySummary(
        entityType: entityType,
        entityDisplayName: entityDisplayName,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    }

    // Fetch all exported goods for aggregation
    final waren = await (_db.select(
      _db.waren,
    )..where((w) => w.id.isIn(exportedItemIds))).get();

    final totalCount = waren.length;

    // Calculate inventory value and count by category
    double totalInventoryValue = 0;
    final categoryCounts = <String, int>{};
    final categoryValues = <String, double>{};
    int belowMinStock = 0;

    for (final w in waren) {
      final value = w.bruttopreis * w.bestand;
      totalInventoryValue += value;

      final kategorie = (w.kategorie?.isNotEmpty == true
          ? w.kategorie
          : 'Unbekannt')!;
      categoryCounts[kategorie] = (categoryCounts[kategorie] ?? 0) + 1;
      categoryValues[kategorie] = (categoryValues[kategorie] ?? 0) + value;

      if (w.bestand < w.mindestbestand) {
        belowMinStock++;
      }
    }

    // Build sections
    final sections = <SummarySection>[
      // Category distribution
      SummarySection(
        title: 'Verteilung nach Kategorie',
        rows: categoryCounts.entries.map((e) {
          final kategorie = e.key;
          final count = e.value;
          final value = categoryValues[kategorie] ?? 0;
          return SummaryRow(
            label: kategorie,
            value: '$count (${_formatCurrency(value)})',
            percentage: totalCount > 0 ? count / totalCount : 0,
            amount: value,
          );
        }).toList(),
        type: SummarySectionType.amountTable,
      ),
      // Summary totals
      SummarySection(
        title: 'Gesamtübersicht',
        rows: [
          SummaryRow.withCurrency(
            label: 'Gesamtinventarwert',
            amount: totalInventoryValue,
          ),
          SummaryRow(
            label: 'Artikel unter Mindestbestand',
            value: '$belowMinStock',
          ),
        ],
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

  String _formatCurrency(double amount) {
    return formatCurrencyEur(amount);
  }
}
