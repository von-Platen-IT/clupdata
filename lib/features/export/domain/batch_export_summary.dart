/// Represents a summary of a batch export operation.
class BatchExportSummary {
  /// Entity type that was exported
  final String entityType;
  
  /// Display name of the entity type
  final String entityDisplayName;
  
  /// Timestamp when the export was performed
  final DateTime exportedAt;
  
  /// Total number of items exported
  final int totalCount;
  
  /// Optional date range filter (from)
  final DateTime? dateFrom;
  
  /// Optional date range filter (to)
  final DateTime? dateTo;
  
  /// Summary sections
  final List<SummarySection> sections;
  
  const BatchExportSummary({
    required this.entityType,
    required this.entityDisplayName,
    required this.exportedAt,
    required this.totalCount,
    this.dateFrom,
    this.dateTo,
    this.sections = const [],
  });
  
  /// Returns a formatted date range string.
  String get dateRangeString {
    if (dateFrom == null && dateTo == null) return 'Alle Datensätze';
    final from = dateFrom != null ? _formatDate(dateFrom!) : 'Anfang';
    final to = dateTo != null ? _formatDate(dateTo!) : 'Heute';
    return '$from - $to';
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

/// A section in the summary (e.g., "Distribution by Status").
class SummarySection {
  /// Title of the section
  final String title;
  
  /// Rows in this section
  final List<SummaryRow> rows;
  
  /// Type of section
  final SummarySectionType type;
  
  const SummarySection({
    required this.title,
    required this.rows,
    this.type = SummarySectionType.table,
  });
}

/// Type of summary section.
enum SummarySectionType {
  /// Simple table with labels and values
  table,
  
  /// Table with monetary amounts
  amountTable,
  
  /// Text block
  text,
}

/// A single row in a summary section.
class SummaryRow {
  /// Label for this row
  final String label;
  
  /// Display value
  final String value;
  
  /// Optional percentage (0.0 - 1.0)
  final double? percentage;
  
  /// Optional monetary amount
  final double? amount;
  
  const SummaryRow({
    required this.label,
    required this.value,
    this.percentage,
    this.amount,
  });
  
  /// Creates a summary row with formatted currency.
  factory SummaryRow.withCurrency({
    required String label,
    required double amount,
    double? percentage,
  }) {
    return SummaryRow(
      label: label,
      value: _formatCurrency(amount),
      percentage: percentage,
      amount: amount,
    );
  }
  
  /// Creates a summary row with count and percentage.
  factory SummaryRow.withPercentage({
    required String label,
    required int count,
    required int total,
  }) {
    final percentage = total > 0 ? count / total : 0.0;
    return SummaryRow(
      label: label,
      value: '$count (${_formatPercentage(percentage)})',
      percentage: percentage,
    );
  }
  
  static String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
  
  static String _formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
  }
}
