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
}
