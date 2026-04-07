import '../../../../core/database/database.dart';
import '../../domain/batch_export_summary.dart';
import '../summary_generator.dart';

/// Generates summary data for Beiträge (contributions) batch exports.
class BeitraegeSummaryGenerator implements SummaryGenerator {
  final AppDatabase _db;

  BeitraegeSummaryGenerator(this._db);

  @override
  String get entityType => 'beitrag';

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

    // Fetch all exported contributions for aggregation
    final beitraege = await (_db.select(_db.beitraege)
          ..where((b) => b.id.isIn(exportedItemIds)))
        .get();

    final totalCount = beitraege.length;

    // Count by status
    final statusCounts = <String, int>{};
    for (final b in beitraege) {
      statusCounts[b.status] = (statusCounts[b.status] ?? 0) + 1;
    }

    // Count by billing period (if available)
    final periodCounts = <String, int>{};
    for (final b in beitraege) {
      if (b.abrechnungsZeitraum != null) {
        final period = '${b.abrechnungsZeitraum!.month}.${b.abrechnungsZeitraum!.year}';
        periodCounts[period] = (periodCounts[period] ?? 0) + 1;
      }
    }

    // Build sections
    final sections = <SummarySection>[
      // Status distribution
      SummarySection(
        title: 'Status',
        rows: statusCounts.entries.map((e) {
          return SummaryRow.withPercentage(
            label: _statusLabel(e.key),
            count: e.value,
            total: totalCount,
          );
        }).toList(),
      ),
      // Billing periods
      if (periodCounts.isNotEmpty)
        SummarySection(
          title: 'Abrechnungszeiträume',
          rows: periodCounts.entries.map((e) {
            return SummaryRow(
              label: e.key,
              value: '${e.value}',
            );
          }).toList(),
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
      case 'kontiert':
        return 'Kontiert';
      case 'offen':
        return 'Offen';
      case 'bezahlt':
        return 'Bezahlt';
      case 'angemahnt':
        return 'Angemahnt';
      case 'storniert':
        return 'Storniert';
      case 'inkasso':
        return 'Inkasso';
      default:
        return status;
    }
  }
}
