import '../domain/batch_export_summary.dart';

/// Abstract interface for generating summary data for batch exports.
///
/// Implementations should query the database for aggregated data
/// and build a [BatchExportSummary] with relevant sections.
abstract class SummaryGenerator {
  /// The entity type this generator handles.
  String get entityType;

  /// Generates a summary for the given exported item IDs.
  Future<BatchExportSummary> generateSummary({
    required List<int> exportedItemIds,
    required String entityDisplayName,
    required DateTime? dateFrom,
    required DateTime? dateTo,
  });

  /// Returns an empty summary for the case when no items were exported.
  ///
  /// Subclasses should call this in their `generateSummary` implementation
  /// when [exportedItemIds] is empty, instead of duplicating the guard.
  static BatchExportSummary emptySummary({
    required String entityType,
    required String entityDisplayName,
    required DateTime? dateFrom,
    required DateTime? dateTo,
  }) {
    return BatchExportSummary(
      entityType: entityType,
      entityDisplayName: entityDisplayName,
      exportedAt: DateTime.now(),
      totalCount: 0,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }
}
