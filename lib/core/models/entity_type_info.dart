/// Centralized entity type information for export, detection, and display.
///
/// Replaces the duplicated `_detectEntityType()` and `_getTitleForEntityType()`
/// methods that existed in [PdfExporter], [BatchPdfExporter], and
/// [BatchExportService].
///
/// Usage:
/// ```dart
/// final type = EntityTypeInfo.detect('Rechnung bearbeiten'); // 'rechnung'
/// final name = EntityTypeInfo.displayNameFor('beitrag');      // 'Beiträge'
/// ```
enum EntityTypeInfo {
  mitglied('Mitglieder'),
  rechnung('Rechnungen'),
  beitrag('Beiträge'),
  leistung('Leistungen'),
  ware('Waren');

  /// German display name shown in UI titles.
  final String displayName;

  const EntityTypeInfo(this.displayName);

  /// Detects the entity type from a name string.
  ///
  /// The [name] is typically a dialog title or entity description.
  /// Returns the matching entity type value or `null` if no match.
  ///
  /// Matching is case-insensitive and uses substring matching.
  static String? detect(String? name) {
    if (name == null) return null;

    final lower = name.toLowerCase();
    for (final type in EntityTypeInfo.values) {
      if (lower.contains(type.name)) {
        return type.name;
      }
    }

    return null;
  }

  /// Returns the German display name for an entity type string.
  ///
  /// Uses case-insensitive matching. Returns [type] unchanged if no match.
  ///
  /// Example: `displayNameFor('beitrag')` → `'Beiträge'`
  static String displayNameFor(String type) {
    final lower = type.toLowerCase();
    for (final info in EntityTypeInfo.values) {
      if (info.name == lower) return info.displayName;
    }
    return type;
  }
}
