import '../../../../core/database/database.dart';
import '../../domain/batch_export_summary.dart';
import '../summary_generator.dart';

/// Generates summary data for Leistungen (services) batch exports.
class LeistungenSummaryGenerator implements SummaryGenerator {
  final AppDatabase _db;

  LeistungenSummaryGenerator(this._db);

  @override
  String get entityType => 'leistung';

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

    // Fetch all exported services for aggregation
    final leistungen = await (_db.select(
      _db.leistung,
    )..where((l) => l.id.isIn(exportedItemIds))).get();

    final totalCount = leistungen.length;

    // Calculate total value (using preisId as placeholder since Leistung doesn't have direct preis field)
    double totalValue = 0;
    for (final _ in leistungen) {
      // Leistung has preisId reference, not direct preis
      // For now, count items only
    }

    // Build sections
    final sections = <SummarySection>[
      SummarySection(
        title: 'Übersicht',
        rows: [
          SummaryRow(label: 'Anzahl Leistungen', value: '$totalCount'),
          SummaryRow.withCurrency(label: 'Gesamtwert', amount: totalValue),
          SummaryRow.withCurrency(
            label: 'Durchschnittspreis',
            amount: totalCount > 0 ? totalValue / totalCount : 0,
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
}
