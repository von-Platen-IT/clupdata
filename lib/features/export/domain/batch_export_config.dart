import '../../../core/models/data_grid_meta_state.dart';

/// Output mode for batch export operations.
enum BatchExportOutputMode {
  /// Save as individual PDF files
  individualFiles,
  
  /// Combine all PDFs into a single file
  combinedPdf,
  
  /// Print directly without saving
  printDirect,
}

/// Configuration for batch export operations.
class BatchExportConfig {
  /// Entity type to export (e.g., 'mitglied', 'rechnung')
  final String entityType;

  /// Optional list of specific item IDs to export (null = all filtered items)
  final List<int>? itemIds;

  /// Metadata state to use for filtering/sorting
  final DataGridMetaState metaState;

  /// Template key to use for all exports
  final String? templateKey;

  /// Output directory for generated PDFs
  final String outputDirectory;

  /// Filename pattern (supports placeholders: {id}, {name}, {date})
  final String filenamePattern;

  /// Whether to combine all PDFs into a single file
  final bool combineIntoSinglePdf;

  /// Output mode for the export
  final BatchExportOutputMode outputMode;

  /// Optional date range filter (from)
  final DateTime? dateFrom;

  /// Optional date range filter (to)
  final DateTime? dateTo;

  /// Whether to include a summary page in the combined PDF
  final bool includeSummary;

  /// Whether to print directly instead of saving
  final bool printDirectly;

  /// Maximum number of items to export per batch
  static const int maxBatchSize = 1000;

  const BatchExportConfig({
    required this.entityType,
    this.itemIds,
    required this.metaState,
    this.templateKey,
    required this.outputDirectory,
    this.filenamePattern = '{entityType}_{id}_{date}.pdf',
    this.combineIntoSinglePdf = false,
    this.outputMode = BatchExportOutputMode.combinedPdf,
    this.dateFrom,
    this.dateTo,
    this.includeSummary = true,
    this.printDirectly = false,
  });

  BatchExportConfig copyWith({
    String? entityType,
    List<int>? itemIds,
    DataGridMetaState? metaState,
    String? templateKey,
    String? outputDirectory,
    String? filenamePattern,
    bool? combineIntoSinglePdf,
    BatchExportOutputMode? outputMode,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? includeSummary,
    bool? printDirectly,
  }) {
    return BatchExportConfig(
      entityType: entityType ?? this.entityType,
      itemIds: itemIds ?? this.itemIds,
      metaState: metaState ?? this.metaState,
      templateKey: templateKey ?? this.templateKey,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      filenamePattern: filenamePattern ?? this.filenamePattern,
      combineIntoSinglePdf: combineIntoSinglePdf ?? this.combineIntoSinglePdf,
      outputMode: outputMode ?? this.outputMode,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      includeSummary: includeSummary ?? this.includeSummary,
      printDirectly: printDirectly ?? this.printDirectly,
    );
  }
  
  /// Returns the display name for the entity type.
  String get entityDisplayName {
    switch (entityType.toLowerCase()) {
      case 'mitglied':
        return 'Mitglieder';
      case 'rechnung':
        return 'Rechnungen';
      case 'beitrag':
        return 'Beiträge';
      case 'leistung':
        return 'Leistungen';
      case 'ware':
        return 'Waren';
      default:
        return entityType;
    }
  }
  
  /// Returns true if date range filtering should be applied.
  bool get hasDateFilter => dateFrom != null || dateTo != null;
}

/// Result of a batch export operation.
class BatchExportResult {
  final int totalItems;
  final int successCount;
  final int errorCount;
  final List<String> generatedFiles;
  final String? combinedFilePath;
  final List<BatchExportError> errors;
  final Duration duration;

  const BatchExportResult({
    required this.totalItems,
    required this.successCount,
    required this.errorCount,
    required this.generatedFiles,
    this.combinedFilePath,
    required this.errors,
    required this.duration,
  });

  bool get hasErrors => errorCount > 0;
  double get successRate => totalItems > 0 ? successCount / totalItems : 0.0;
}

/// Error that occurred during batch export.
class BatchExportError {
  final int itemId;
  final String error;
  final String? stackTrace;

  const BatchExportError({
    required this.itemId,
    required this.error,
    this.stackTrace,
  });

  @override
  String toString() => 'BatchExportError(item: $itemId, error: $error)';
}
