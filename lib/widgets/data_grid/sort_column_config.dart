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
}
