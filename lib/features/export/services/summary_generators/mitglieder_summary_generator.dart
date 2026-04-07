import '../../../../core/database/database.dart';
import '../../domain/batch_export_summary.dart';
import '../summary_generator.dart';

/// Generates summary data for Mitglieder (members) batch exports.
class MitgliederSummaryGenerator implements SummaryGenerator {
  final AppDatabase _db;

  MitgliederSummaryGenerator(this._db);

  @override
  String get entityType => 'mitglied';

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

    // Fetch all exported members for aggregation
    final mitglieder = await (_db.select(_db.mitglieds)
          ..where((m) => m.id.isIn(exportedItemIds)))
        .get();

    final totalCount = mitglieder.length;

    // Count by gender
    final genderCounts = <String, int>{};
    for (final m in mitglieder) {
      final gender = m.geschlecht ?? 'unbekannt';
      genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;
    }

    // Count by location (top 10)
    final ortCounts = <String, int>{};
    for (final m in mitglieder) {
      final ort = m.ort?.isNotEmpty == true ? m.ort! : 'Unbekannt';
      ortCounts[ort] = (ortCounts[ort] ?? 0) + 1;
    }
    final topOrte = ortCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10Orte = topOrte.take(10).toList();

    // Build sections
    final sections = <SummarySection>[
      // Gender distribution
      SummarySection(
        title: 'Verteilung nach Geschlecht',
        rows: genderCounts.entries.map((e) {
          return SummaryRow.withPercentage(
            label: _genderLabel(e.key),
            count: e.value,
            total: totalCount,
          );
        }).toList(),
      ),
      // Top locations
      SummarySection(
        title: 'Verteilung nach Ort (Top 10)',
        rows: top10Orte.map((e) {
          return SummaryRow.withPercentage(
            label: e.key,
            count: e.value,
            total: totalCount,
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

  String _genderLabel(String gender) {
    switch (gender.toLowerCase()) {
      case 'maennlich':
        return 'Männlich';
      case 'weiblich':
        return 'Weiblich';
      case 'divers':
        return 'Divers';
      case 'unbekannt':
        return 'Unbekannt';
      default:
        return gender;
    }
  }
}
