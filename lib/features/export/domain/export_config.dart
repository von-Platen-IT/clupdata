class ExportConfig {
  /// The item to export (for details) or null for lists.
  final dynamic item;

  /// The entity type identifier (e.g., 'mitglied', 'rechnung').
  final String entityType;

  /// The display title for the export.
  final String title;

  /// Optional subtitle or description.
  final String? subtitle;

  const ExportConfig({
    this.item,
    required this.entityType,
    required this.title,
    this.subtitle,
  });
}
