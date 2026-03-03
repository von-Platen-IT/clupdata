class SortColumnConfig {
  final String field;
  final String label;
  bool enabled;
  bool ascending;
  int priority;

  SortColumnConfig({
    required this.field,
    required this.label,
    this.enabled = false,
    this.ascending = true,
    this.priority = 0,
  });

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
}
