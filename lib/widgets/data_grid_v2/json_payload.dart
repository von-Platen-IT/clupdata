import 'dart:convert';

/// Standardized JSON payload structure for data exchange.
///
/// Every JSON payload processed or emitted by [VpitDataGrid] follows this
/// exact structure as defined in the DataGrid specification (Section 3.1):
/// ```json
/// {
///   "action": "OPTIONAL_STRING",
///   "metadata": { "columns": [...], "active_sort": [...], "active_filters": [...] },
///   "data": "PAYLOAD"
/// }
/// ```
class DataGridJsonPayload {
  /// Optional action identifier (e.g., SET_STATE, CREATE, UPDATE, DELETE).
  final String? action;

  /// Metadata about column configuration, active sorting, and active filters.
  final DataGridJsonMetadata metadata;

  /// The actual data payload — either a List of items or a single item Map.
  final dynamic data;

  const DataGridJsonPayload({
    this.action,
    required this.metadata,
    required this.data,
  });

  /// Serializes this payload to a JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toMap());

  /// Converts to a Map representation.
  Map<String, dynamic> toMap() => {
        if (action != null) 'action': action,
        'metadata': metadata.toMap(),
        'data': data,
      };

  /// Deserializes from a JSON string.
  factory DataGridJsonPayload.fromJsonString(String json) {
    return DataGridJsonPayload.fromMap(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Deserializes from a Map.
  factory DataGridJsonPayload.fromMap(Map<String, dynamic> map) {
    return DataGridJsonPayload(
      action: map['action'] as String?,
      metadata: DataGridJsonMetadata.fromMap(
        map['metadata'] as Map<String, dynamic>? ?? {},
      ),
      data: map['data'],
    );
  }
}

/// Metadata section of the [DataGridJsonPayload].
///
/// Carries structural information about columns, active sort chain,
/// and active column filters.
class DataGridJsonMetadata {
  /// Column definitions with field, title, and editability flags.
  final List<Map<String, dynamic>> columns;

  /// Currently active sort configurations (field, direction, priority).
  final List<Map<String, dynamic>> activeSort;

  /// Currently active column filters (field → value pairs).
  final List<Map<String, dynamic>> activeFilters;

  const DataGridJsonMetadata({
    this.columns = const [],
    this.activeSort = const [],
    this.activeFilters = const [],
  });

  /// Converts to a Map representation.
  Map<String, dynamic> toMap() => {
        'columns': columns,
        'active_sort': activeSort,
        'active_filters': activeFilters,
      };

  /// Deserializes from a Map.
  factory DataGridJsonMetadata.fromMap(Map<String, dynamic> map) {
    return DataGridJsonMetadata(
      columns:
          (map['columns'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      activeSort: (map['active_sort'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [],
      activeFilters: (map['active_filters'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [],
    );
  }
}
