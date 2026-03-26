import 'package:intl/intl.dart';

import '../../sort_column_config.dart';

/// Context object containing metadata for PDF export generation.
///
/// Passed to [PdfTemplate.generate] to provide additional information
/// about the export request (title, filters, timestamp, etc.).
///
/// This context enables templates to include contextual information
/// such as applied filters, sort order, and export timestamp in the
/// generated PDF.
class PdfExportContext {
  /// The title of the export (e.g., "Mitgliederliste", "Rechnungsübersicht").
  final String title;

  /// The timestamp when the export was initiated.
  final DateTime exportTimestamp;

  /// Active column filters at the time of export (field → value).
  final Map<String, String>? activeFilters;

  /// Active sort configurations at the time of export.
  final List<SortColumnConfig>? activeSorts;

  /// Whether this is a detail view export (single item) or list export.
  final bool isDetailView;

  /// Optional entity name for detail exports (e.g., "Mitglied", "Rechnung").
  final String? entityName;

  /// Creates a [PdfExportContext] with the given metadata.
  const PdfExportContext({
    required this.title,
    required this.exportTimestamp,
    this.activeFilters,
    this.activeSorts,
    this.isDetailView = false,
    this.entityName,
  });

  /// Returns the formatted export timestamp using German locale.
  ///
  /// Format: "24.03.2026 14:30"
  String get formattedTimestamp {
    return DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(exportTimestamp);
  }

  /// Returns the formatted date portion only.
  ///
  /// Format: "24.03.2026"
  String get formattedDate {
    return DateFormat('dd.MM.yyyy', 'de_DE').format(exportTimestamp);
  }

  /// Returns a human-readable description of applied filters.
  ///
  /// Example: "Status: Bezahlt, Betrag > 100"
  String? get filterDescription {
    if (activeFilters == null || activeFilters!.isEmpty) {
      return null;
    }
    return activeFilters!.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  /// Returns a human-readable description of sort order.
  ///
  /// Example: "Name ↑, Datum ↓"
  String? get sortDescription {
    if (activeSorts == null || activeSorts!.isEmpty) {
      return null;
    }
    final enabledSorts = activeSorts!.where((s) => s.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (enabledSorts.isEmpty) return null;

    return enabledSorts
        .map((s) => '${s.label} ${s.ascending ? '↑' : '↓'}')
        .join(', ');
  }
}
