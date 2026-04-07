import '../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../../widgets/data_grid_v2/sort_column_config.dart';

/// Immutable state object holding DataGrid metadata for export purposes.
///
/// This model decouples export metadata from the UI state, enabling
/// headless export functionality and batch processing.
///
/// Note: Column configurations contain function references (valueExtractor)
/// that cannot be serialized. The [allColumns] and [visibleColumns] are
/// kept in memory only and not persisted.
class DataGridMetaState {
  /// Entity type identifier (e.g., 'mitglied', 'rechnung')
  final String entityType;

  /// Active column filters (field → value)
  final Map<String, String> activeFilters;

  /// Active sort configurations
  final List<SortColumnConfig> activeSorts;

  /// List of visible column field names (in display order)
  final List<String> visibleColumns;

  /// Full list of available column configurations.
  /// Note: These contain function references and cannot be serialized.
  final List<DataGridColumnConfig> allColumns;

  /// Current search text
  final String searchText;

  const DataGridMetaState({
    required this.entityType,
    this.activeFilters = const {},
    this.activeSorts = const [],
    required this.visibleColumns,
    required this.allColumns,
    this.searchText = '',
  });

  /// Creates a copy of this state with the given fields replaced.
  DataGridMetaState copyWith({
    String? entityType,
    Map<String, String>? activeFilters,
    List<SortColumnConfig>? activeSorts,
    List<String>? visibleColumns,
    List<DataGridColumnConfig>? allColumns,
    String? searchText,
  }) {
    return DataGridMetaState(
      entityType: entityType ?? this.entityType,
      activeFilters: activeFilters ?? this.activeFilters,
      activeSorts: activeSorts ?? this.activeSorts,
      visibleColumns: visibleColumns ?? this.visibleColumns,
      allColumns: allColumns ?? this.allColumns,
      searchText: searchText ?? this.searchText,
    );
  }

  /// Returns the visible column configs in display order.
  List<DataGridColumnConfig> get visibleColumnConfigs {
    return allColumns
        .where((c) => visibleColumns.contains(c.field))
        .toList();
  }

  /// Returns all column configs in original order.
  List<DataGridColumnConfig> get allColumnConfigs => allColumns;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataGridMetaState &&
        other.entityType == entityType &&
        _mapEquals(other.activeFilters, activeFilters) &&
        _listEquals(other.activeSorts, activeSorts) &&
        _listEquals(other.visibleColumns, visibleColumns) &&
        other.searchText == searchText;
  }

  @override
  int get hashCode {
    return entityType.hashCode ^
        activeFilters.hashCode ^
        activeSorts.hashCode ^
        visibleColumns.hashCode ^
        searchText.hashCode;
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  bool _listEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Converts serializable parts of this state to a JSON-compatible map.
  /// Note: Column configurations are NOT included due to function references.
  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType,
      'activeFilters': activeFilters,
      'activeSorts': activeSorts.map((s) => s.toMap()).toList(),
      'visibleColumns': visibleColumns,
      'searchText': searchText,
    };
  }

  /// Creates a [DataGridMetaState] from a JSON-compatible map.
  /// Note: [allColumns] must be re-provided separately as they contain
  /// function references that cannot be serialized.
  factory DataGridMetaState.fromJson(
    Map<String, dynamic> json, {
    required List<DataGridColumnConfig> allColumns,
  }) {
    return DataGridMetaState(
      entityType: json['entityType'] as String,
      activeFilters: Map<String, String>.from(json['activeFilters'] as Map),
      activeSorts: (json['activeSorts'] as List)
          .map((s) => SortColumnConfig.fromMap(s as Map<String, dynamic>))
          .toList(),
      visibleColumns: (json['visibleColumns'] as List)
          .map((e) => e as String)
          .toList(),
      allColumns: allColumns,
      searchText: json['searchText'] as String? ?? '',
    );
  }
}
