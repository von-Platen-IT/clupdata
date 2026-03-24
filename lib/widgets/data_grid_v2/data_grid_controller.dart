import 'dart:io';

import 'package:flutter/foundation.dart';

import 'data_grid_column_config.dart';
import 'export/export_data_table.dart';
import 'json_payload.dart';
import 'sort_column_config.dart';

/// Headless controller for [VpitDataGrid] that manages search, filter,
/// and sort state programmatically.
///
/// Provides a complete bidirectional JSON API (Section 3) and file I/O
/// (Section 3.4) as specified in the DataGrid rules. External code can
/// use this controller to fully control the grid without user interaction.
///
/// Usage:
/// ```dart
/// final controller = DataGridController<MyItem>(
///   columnConfigs: myColumns,
///   toJson: (item) => item.toJson(),
///   fromJson: MyItem.fromJson,
///   toSearchString: (item) => '${item.name} ${item.category}',
/// );
/// ```
class DataGridController<T> extends ChangeNotifier {
  // ── Configuration ──────────────────────────────────────────────────────

  List<DataGridColumnConfig<T>> _columnConfigs;
  final Map<String, dynamic> Function(T item) _toJson;
  final T Function(Map<String, dynamic> json) _fromJson;
  final String Function(T item) _toSearchString;

  // ── CRUD Callbacks (Persistence Delegation, Section 2.3) ───────────────

  /// Called when a new item should be persisted.
  void Function(T item)? onItemCreated;

  /// Called when an existing item should be updated.
  void Function(T item)? onItemUpdated;

  /// Called when an item should be deleted.
  void Function(T item)? onItemDeleted;

  // ── Internal State ─────────────────────────────────────────────────────

  String _searchText = '';
  Map<String, String> _activeFilters = {};
  List<SortColumnConfig> _sortConfigs = [];
  List<T> _items = [];
  List<T> _filteredSortedItems = [];

  /// Creates a [DataGridController] with the given configuration.
  ///
  /// [columnConfigs] defines the columns and their value extractors.
  /// [toJson] / [fromJson] enable JSON serialization for the API.
  /// [toSearchString] builds the full-text search string per item.
  DataGridController({
    required List<DataGridColumnConfig<T>> columnConfigs,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    required String Function(T item) toSearchString,
    this.onItemCreated,
    this.onItemUpdated,
    this.onItemDeleted,
  })  : _columnConfigs = List.from(columnConfigs),
        _toJson = toJson,
        _fromJson = fromJson,
        _toSearchString = toSearchString {
    _sortConfigs = columnConfigs
        .where((c) => c.sortable)
        .map((c) => SortColumnConfig(field: c.field, label: c.title))
        .toList();
  }

  // ── Getters ────────────────────────────────────────────────────────────

  /// The current full-text search query.
  String get searchText => _searchText;

  /// The currently active column filters (field → value).
  Map<String, String> get activeFilters => Map.unmodifiable(_activeFilters);

  /// The current sort chain configuration.
  List<SortColumnConfig> get sortConfigs => _sortConfigs;

  /// The raw, unfiltered items.
  List<T> get items => _items;

  /// The items after applying search, filters, and sorting.
  List<T> get filteredSortedItems => _filteredSortedItems;

  /// The column configurations.
  List<DataGridColumnConfig<T>> get columnConfigs => _columnConfigs;

  // ── Setters (trigger recompute + notify) ───────────────────────────────

  /// Updates the full-text search query and recomputes the filtered view.
  set searchText(String value) {
    if (_searchText == value) return;
    _searchText = value;
    _recompute();
    notifyListeners();
  }

  /// Replaces the active column filters and recomputes the filtered view.
  set activeFilters(Map<String, String> value) {
    _activeFilters = Map.from(value);
    _recompute();
    notifyListeners();
  }

  /// Replaces the sort chain and recomputes the sorted view.
  set sortConfigs(List<SortColumnConfig> value) {
    _sortConfigs = value.map((c) => c.copyWith()).toList();
    _recompute();
    notifyListeners();
  }

  /// Replaces the raw items list. Triggers recompute of filtered/sorted view.
  void updateItems(List<T> newItems) {
    _items = List.from(newItems);
    _recompute();
    notifyListeners();
  }

  /// Updates column configurations at runtime.
  void updateColumnConfigs(List<DataGridColumnConfig<T>> configs) {
    _columnConfigs = List.from(configs);
    notifyListeners();
  }

  // ── Recompute filtered + sorted items ──────────────────────────────────

  void _recompute() {
    var result = List<T>.from(_items);

    // 1. Apply column filters (AND logic)
    if (_activeFilters.isNotEmpty) {
      result = result.where((item) {
        for (final entry in _activeFilters.entries) {
          if (entry.value.isEmpty) continue;
          final filterValue = entry.value.toLowerCase();
          final config =
              _columnConfigs.where((c) => c.field == entry.key).firstOrNull;
          if (config == null) continue;
          final cellValue =
              config.valueExtractor(item)?.toString().toLowerCase() ?? '';
          if (!cellValue.contains(filterValue)) return false;
        }
        return true;
      }).toList();
    }

    // 2. Apply full-text search
    if (_searchText.isNotEmpty) {
      final query = _searchText.toLowerCase();
      result = result.where((item) {
        return _toSearchString(item).toLowerCase().contains(query);
      }).toList();
    }

    // 3. Apply multi-column sort chain (sorted by priority ascending)
    final sortChain = _sortConfigs.where((c) => c.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (sortChain.isNotEmpty) {
      result.sort((a, b) {
        for (final col in sortChain) {
          final config =
              _columnConfigs.where((c) => c.field == col.field).firstOrNull;
          if (config == null) continue;
          final valA = config.valueExtractor(a);
          final valB = config.valueExtractor(b);
          int cmp;
          if (valA is Comparable && valB is Comparable) {
            cmp = valA.compareTo(valB);
          } else {
            cmp = valA?.toString().compareTo(valB?.toString() ?? '') ?? 0;
          }
          if (cmp != 0) return col.ascending ? cmp : -cmp;
        }
        return 0;
      });
    }

    _filteredSortedItems = result;
  }

  // ── JSON Outbound API (Section 3.2) ────────────────────────────────────

  /// Returns the currently sorted/filtered data as a JSON string.
  ///
  /// The payload includes metadata (columns, active sort, active filters)
  /// and the data array serialized via the configured [toJson] function.
  String getExportJson() {
    final payload = DataGridJsonPayload(
      metadata: _buildMetadata(),
      data: _filteredSortedItems.map(_toJson).toList(),
    );
    return payload.toJsonString();
  }

  /// Returns a single [item] as a JSON string with metadata.
  String getDetailJson(T item) {
    final payload = DataGridJsonPayload(
      action: 'DETAIL',
      metadata: _buildMetadata(),
      data: _toJson(item),
    );
    return payload.toJsonString();
  }

  // ── JSON Inbound API (Section 3.3) ─────────────────────────────────────

  /// Programmatically overwrites the UI filters and sorting from a
  /// JSON string conforming to the [DataGridJsonPayload] format.
  void applyStateFromJson(String json) {
    final payload = DataGridJsonPayload.fromJsonString(json);

    // Apply filters
    final filterEntries = payload.metadata.activeFilters;
    _activeFilters = {
      for (final f in filterEntries)
        if (f['field'] is String && f['value'] is String)
          f['field'] as String: f['value'] as String,
    };

    // Apply sort
    final sortEntries = payload.metadata.activeSort;
    for (final s in sortEntries) {
      final field = s['field'] as String?;
      if (field == null) continue;
      final config =
          _sortConfigs.where((c) => c.field == field).firstOrNull;
      if (config != null) {
        config.enabled = s['enabled'] as bool? ?? false;
        config.ascending = s['ascending'] as bool? ?? true;
        config.priority = s['priority'] as int? ?? 0;
      }
    }

    _recompute();
    notifyListeners();
  }

  /// Executes a CRUD operation described by the JSON [action] field and
  /// triggers the corresponding persistence callback (Section 2.3).
  ///
  /// Supported actions: CREATE, UPDATE, DELETE.
  void executeCrudFromJson(String json) {
    final payload = DataGridJsonPayload.fromJsonString(json);
    final action = payload.action?.toUpperCase();

    switch (action) {
      case 'CREATE':
        final item = _fromJson(payload.data as Map<String, dynamic>);
        onItemCreated?.call(item);
      case 'UPDATE':
        final item = _fromJson(payload.data as Map<String, dynamic>);
        onItemUpdated?.call(item);
      case 'DELETE':
        final item = _fromJson(payload.data as Map<String, dynamic>);
        onItemDeleted?.call(item);
      default:
        throw ArgumentError('Unknown CRUD action: $action');
    }
  }

  // ── File I/O (Section 3.4) ─────────────────────────────────────────────

  /// Dumps the current JSON payload to a local text file at [filePath].
  Future<void> exportToFile(String filePath) async {
    final file = File(filePath);
    await file.writeAsString(getExportJson());
  }

  /// Loads state (filters, sorting) from a text file at [filePath].
  ///
  /// Throws [FileSystemException] if the file does not exist.
  Future<void> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    final json = await file.readAsString();
    applyStateFromJson(json);
  }

  // ── Export API ─────────────────────────────────────────────────────────

  /// Converts the controller's data into a type-safe [ExportDataTable].
  ///
  /// When [visibleOnly] is true (default), only the currently filtered and
  /// sorted items are exported. Set to false to export all raw items.
  ///
  /// This method lives on the controller (not an external adapter) because
  /// it needs access to the correctly typed [DataGridColumnConfig<T>]
  /// value extractors. Calling from a `DataGridController<dynamic>` context
  /// would cause a runtime type mismatch.
  ExportDataTable toExportDataTable({
    String title = '',
    bool visibleOnly = true,
  }) {
    final source = visibleOnly ? _filteredSortedItems : _items;
    final headers = _columnConfigs.map((c) => c.title).toList();

    final rows = source.map((item) {
      return _columnConfigs.map((config) {
        final rawValue = config.valueExtractor(item);
        if (config.formatter != null) {
          return config.formatter!(rawValue);
        }
        return rawValue?.toString() ?? '';
      }).toList();
    }).toList();

    return ExportDataTable(
      title: title,
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  DataGridJsonMetadata _buildMetadata() {
    return DataGridJsonMetadata(
      columns: _columnConfigs.map((c) => c.toMetadataMap()).toList(),
      activeSort: _sortConfigs
          .where((c) => c.enabled)
          .map((c) => c.toMap())
          .toList(),
      activeFilters: _activeFilters.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => {'field': e.key, 'value': e.value})
          .toList(),
    );
  }
}
