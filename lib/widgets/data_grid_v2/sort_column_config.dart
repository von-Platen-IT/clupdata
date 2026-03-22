/// Configuration for a single sortable column in the multi-sort chain.
///
/// Used by [DataGridController] and [SortSettingsDialog] to track
/// which columns are actively sorted, their direction, and priority.
class SortColumnConfig {
  /// The column field identifier (matches [DataGridColumnConfig.field]).
  final String field;

  /// Human-readable label shown in the sort dialog.
  final String label;

  /// Whether this column is currently active in the sort chain.
  bool enabled;

  /// Sort direction — `true` for ascending, `false` for descending.
  bool ascending;

  /// Sort priority — lower values are applied first.
  int priority;

  SortColumnConfig({
    required this.field,
    required this.label,
    this.enabled = false,
    this.ascending = true,
    this.priority = 0,
  });

  /// Creates a shallow copy with optional overrides.
  SortColumnConfig copyWith({
    String? field,
    String? label,
    bool? enabled,
    bool? ascending,
    int? priority,
  }) {
    return SortColumnConfig(
      field: field ?? this.field,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      ascending: ascending ?? this.ascending,
      priority: priority ?? this.priority,
    );
  }

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toMap() => {
        'field': field,
        'label': label,
        'enabled': enabled,
        'ascending': ascending,
        'priority': priority,
      };

  /// Deserializes from a JSON-compatible map.
  factory SortColumnConfig.fromMap(Map<String, dynamic> map) {
    return SortColumnConfig(
      field: map['field'] as String,
      label: map['label'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? false,
      ascending: map['ascending'] as bool? ?? true,
      priority: map['priority'] as int? ?? 0,
    );
  }
}
