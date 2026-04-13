import 'package:drift/drift.dart';

import '../../core/database/database.dart';
import '../../widgets/data_grid_v2/export/export_data_table.dart';
import '../../core/models/data_grid_meta_state.dart';
import '../../widgets/data_grid_v2/sort_column_config.dart';

/// Generic repository for fetching data for export purposes.
///
/// Applies filters and sorts at the database level for efficiency,
/// enabling headless export functionality independent of the UI.
class ExportDataRepository {
  final AppDatabase _db;

  ExportDataRepository(this._db);

  /// Fetches data for export based on metadata state.
  ///
  /// [entityType] identifies the table (e.g., 'mitglied', 'rechnung')
  /// [metaState] contains filters, sorts, and column configurations
  /// [includeAllColumns] if true, returns all columns; otherwise only visible ones
  Future<ExportDataTable> fetchDataForExport({
    required String entityType,
    required DataGridMetaState metaState,
    bool includeAllColumns = false,
  }) async {
    switch (entityType.toLowerCase()) {
      case 'mitglied':
        return _fetchMitgliederData(metaState, includeAllColumns);
      case 'rechnung':
        return _fetchRechnungenData(metaState, includeAllColumns);
      case 'beitrag':
        return _fetchBeitraegeData(metaState, includeAllColumns);
      case 'leistung':
        return _fetchLeistungenData(metaState, includeAllColumns);
      case 'ware':
        return _fetchWarenData(metaState, includeAllColumns);
      default:
        throw ArgumentError('Unknown entity type: $entityType');
    }
  }

  /// Fetches a single item by ID for detail export.
  Future<ExportDataTable> fetchSingleItemForExport({
    required String entityType,
    required int itemId,
    required DataGridMetaState metaState,
  }) async {
    switch (entityType.toLowerCase()) {
      case 'mitglied':
        return _fetchSingleMitglied(itemId, metaState);
      case 'rechnung':
        return _fetchSingleRechnung(itemId, metaState);
      case 'beitrag':
        return _fetchSingleBeitrag(itemId, metaState);
      case 'leistung':
        return _fetchSingleLeistung(itemId, metaState);
      case 'ware':
        return _fetchSingleWare(itemId, metaState);
      default:
        throw ArgumentError('Unknown entity type: $entityType');
    }
  }

  /// Fetches item IDs matching the current filters for batch export.
  ///
  /// [dateFrom] and [dateTo] allow filtering by date range.
  /// The date field used depends on the entity type.
  Future<List<int>> fetchItemIdsForExport({
    required String entityType,
    required DataGridMetaState metaState,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    switch (entityType.toLowerCase()) {
      case 'mitglied':
        return _fetchMitgliedIds(metaState, dateFrom: dateFrom, dateTo: dateTo);
      case 'rechnung':
        return _fetchRechnungIds(metaState, dateFrom: dateFrom, dateTo: dateTo);
      case 'beitrag':
        return _fetchBeitragIds(metaState, dateFrom: dateFrom, dateTo: dateTo);
      case 'leistung':
        return _fetchLeistungIds(metaState);
      case 'ware':
        return _fetchWareIds(metaState);
      default:
        throw ArgumentError('Unknown entity type: $entityType');
    }
  }

  // ── Mitglieder ──────────────────────────────────────────────────────────

  Future<ExportDataTable> _fetchMitgliederData(
    DataGridMetaState metaState,
    bool includeAllColumns,
  ) async {
    var query = _db.select(_db.mitglieds);
    query = _applyMitgliedFilters(query, metaState.activeFilters);
    query = _applyMitgliedSorts(query, metaState.activeSorts);

    final results = await query.get();

    final columnsToInclude = _getColumnsToInclude(metaState, includeAllColumns);
    final headers = columnsToInclude.map((c) => c.title as String).toList();
    final rows = results
        .map((mitglied) {
          return columnsToInclude
              .map((config) {
                final rawValue = config.valueExtractor(mitglied);
                if (config.formatter != null) {
                  return config.formatter!(rawValue) as String;
                }
                return rawValue?.toString() ?? '';
              })
              .toList()
              .cast<String>();
        })
        .toList()
        .cast<List<String>>();

    return ExportDataTable(
      title: 'Mitglieder',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<ExportDataTable> _fetchSingleMitglied(
    int itemId,
    DataGridMetaState metaState,
  ) async {
    final mitglied = await (_db.select(
      _db.mitglieds,
    )..where((m) => m.id.equals(itemId))).getSingleOrNull();

    if (mitglied == null) {
      return ExportDataTable(
        title: 'Mitglied - Detail',
        headers: [],
        rows: [],
        exportedAt: DateTime.now(),
      );
    }

    final columnsToInclude = metaState.allColumns;
    final headers = columnsToInclude.map((c) => c.title).toList();
    final rows = [
      columnsToInclude.map((config) {
        final rawValue = config.valueExtractor(mitglied);
        if (config.formatter != null) return config.formatter!(rawValue);
        return rawValue?.toString() ?? '';
      }).toList(),
    ];

    return ExportDataTable(
      title: 'Mitglied - Detail',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<List<int>> _fetchMitgliedIds(
    DataGridMetaState metaState, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    var query = _db.select(_db.mitglieds);
    query = _applyMitgliedFilters(query, metaState.activeFilters);
    query = _applyMitgliedSorts(query, metaState.activeSorts);

    // Apply date range filter on vertragLaufzeitVon
    if (dateFrom != null) {
      query = query
        ..where((m) => m.vertragLaufzeitVon.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query = query
        ..where((m) => m.vertragLaufzeitVon.isSmallerOrEqualValue(dateTo));
    }

    final results = await query.get();
    return results.map((m) => m.id).toList();
  }

  SimpleSelectStatement<$MitgliedsTable, Mitglied> _applyMitgliedFilters(
    SimpleSelectStatement<$MitgliedsTable, Mitglied> query,
    Map<String, String> filters,
  ) {
    for (final entry in filters.entries) {
      final field = entry.key;
      final value = entry.value.toLowerCase();

      if (value.isEmpty) continue;

      switch (field) {
        case 'name':
          query = query..where((m) => m.name.lower().contains(value));
          break;
        case 'vorname':
          query = query..where((m) => m.vorname.lower().contains(value));
          break;
        case 'ort':
          query = query..where((m) => m.ort.lower().contains(value));
          break;
        case 'email':
          query = query..where((m) => m.email.lower().contains(value));
          break;
        case 'telefon1':
          query = query..where((m) => m.telefon1.lower().contains(value));
          break;
        case 'leistung_name':
          // Join with leistung table for filtering
          break;
      }
    }
    return query;
  }

  SimpleSelectStatement<$MitgliedsTable, Mitglied> _applyMitgliedSorts(
    SimpleSelectStatement<$MitgliedsTable, Mitglied> query,
    List<SortColumnConfig> sorts,
  ) {
    final activeSorts = sorts.where((s) => s.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (activeSorts.isEmpty) return query;

    final orderings = activeSorts.map((sort) {
      switch (sort.field) {
        case 'name':
          return (m) => OrderingTerm(
            expression: m.name,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        case 'vorname':
          return (m) => OrderingTerm(
            expression: m.vorname,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        case 'ort':
          return (m) => OrderingTerm(
            expression: m.ort,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        default:
          return (m) => OrderingTerm(expression: m.id);
      }
    }).toList();

    query = query..orderBy(orderings);
    return query;
  }

  // ── Rechnungen ──────────────────────────────────────────────────────────

  Future<ExportDataTable> _fetchRechnungenData(
    DataGridMetaState metaState,
    bool includeAllColumns,
  ) async {
    var query = _db.select(_db.rechnungen);
    query = _applyRechnungFilters(query, metaState.activeFilters);
    query = _applyRechnungSorts(query, metaState.activeSorts);

    final results = await query.get();

    final columnsToInclude = _getColumnsToInclude(metaState, includeAllColumns);
    final headers = columnsToInclude.map((c) => c.title as String).toList();
    final rows = results
        .map((rechnung) {
          return columnsToInclude
              .map((config) {
                final rawValue = config.valueExtractor(rechnung);
                if (config.formatter != null) {
                  return config.formatter!(rawValue) as String;
                }
                return rawValue?.toString() ?? '';
              })
              .toList()
              .cast<String>();
        })
        .toList()
        .cast<List<String>>();

    return ExportDataTable(
      title: 'Rechnungen',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<ExportDataTable> _fetchSingleRechnung(
    int itemId,
    DataGridMetaState metaState,
  ) async {
    final rechnung = await (_db.select(
      _db.rechnungen,
    )..where((r) => r.id.equals(itemId))).getSingleOrNull();

    if (rechnung == null) {
      return ExportDataTable(
        title: 'Rechnung - Detail',
        headers: [],
        rows: [],
        exportedAt: DateTime.now(),
      );
    }

    final columnsToInclude = metaState.allColumns;
    final headers = columnsToInclude.map((c) => c.title).toList();
    final rows = [
      columnsToInclude.map((config) {
        final rawValue = config.valueExtractor(rechnung);
        if (config.formatter != null) return config.formatter!(rawValue);
        return rawValue?.toString() ?? '';
      }).toList(),
    ];

    return ExportDataTable(
      title: 'Rechnung - Detail',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<List<int>> _fetchRechnungIds(
    DataGridMetaState metaState, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    var query = _db.select(_db.rechnungen);
    query = _applyRechnungFilters(query, metaState.activeFilters);
    query = _applyRechnungSorts(query, metaState.activeSorts);

    // Apply date range filter on datum
    if (dateFrom != null) {
      query = query..where((r) => r.datum.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query = query..where((r) => r.datum.isSmallerOrEqualValue(dateTo));
    }

    final results = await query.get();
    return results.map((r) => r.id).toList();
  }

  SimpleSelectStatement<$RechnungenTable, Rechnung> _applyRechnungFilters(
    SimpleSelectStatement<$RechnungenTable, Rechnung> query,
    Map<String, String> filters,
  ) {
    for (final entry in filters.entries) {
      final field = entry.key;
      final value = entry.value.toLowerCase();

      if (value.isEmpty) continue;

      switch (field) {
        case 'rechnungsnummer':
          query = query
            ..where((r) => r.rechnungsnummer.lower().contains(value));
          break;
        case 'status':
          query = query..where((r) => r.status.lower().contains(value));
          break;
      }
    }
    return query;
  }

  SimpleSelectStatement<$RechnungenTable, Rechnung> _applyRechnungSorts(
    SimpleSelectStatement<$RechnungenTable, Rechnung> query,
    List<SortColumnConfig> sorts,
  ) {
    final activeSorts = sorts.where((s) => s.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (activeSorts.isEmpty) return query;

    final orderings = activeSorts.map((sort) {
      switch (sort.field) {
        case 'rechnungsnummer':
          return (r) => OrderingTerm(
            expression: r.rechnungsnummer,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        case 'datum':
          return (r) => OrderingTerm(
            expression: r.datum,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        case 'status':
          return (r) => OrderingTerm(
            expression: r.status,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        default:
          return (r) => OrderingTerm(expression: r.id);
      }
    }).toList();

    query = query..orderBy(orderings);
    return query;
  }

  // ── Beiträge ────────────────────────────────────────────────────────────

  Future<ExportDataTable> _fetchBeitraegeData(
    DataGridMetaState metaState,
    bool includeAllColumns,
  ) async {
    var query = _db.select(_db.beitraege);
    query = _applyBeitragFilters(query, metaState.activeFilters);
    query = _applyBeitragSorts(query, metaState.activeSorts);

    final results = await query.get();

    final columnsToInclude = _getColumnsToInclude(metaState, includeAllColumns);
    final headers = columnsToInclude.map((c) => c.title as String).toList();
    final rows = results
        .map((beitrag) {
          return columnsToInclude
              .map((config) {
                final rawValue = config.valueExtractor(beitrag);
                if (config.formatter != null) {
                  return config.formatter!(rawValue) as String;
                }
                return rawValue?.toString() ?? '';
              })
              .toList()
              .cast<String>();
        })
        .toList()
        .cast<List<String>>();

    return ExportDataTable(
      title: 'Beiträge',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<ExportDataTable> _fetchSingleBeitrag(
    int itemId,
    DataGridMetaState metaState,
  ) async {
    final beitrag = await (_db.select(
      _db.beitraege,
    )..where((b) => b.id.equals(itemId))).getSingleOrNull();

    if (beitrag == null) {
      return ExportDataTable(
        title: 'Beitrag - Detail',
        headers: [],
        rows: [],
        exportedAt: DateTime.now(),
      );
    }

    final columnsToInclude = metaState.allColumns;
    final headers = columnsToInclude.map((c) => c.title).toList();
    final rows = [
      columnsToInclude.map((config) {
        final rawValue = config.valueExtractor(beitrag);
        if (config.formatter != null) return config.formatter!(rawValue);
        return rawValue?.toString() ?? '';
      }).toList(),
    ];

    return ExportDataTable(
      title: 'Beitrag - Detail',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<List<int>> _fetchBeitragIds(
    DataGridMetaState metaState, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    var query = _db.select(_db.beitraege);
    query = _applyBeitragFilters(query, metaState.activeFilters);
    query = _applyBeitragSorts(query, metaState.activeSorts);

    // Apply date range filter on kontiertAm
    if (dateFrom != null) {
      query = query..where((b) => b.kontiertAm.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query = query..where((b) => b.kontiertAm.isSmallerOrEqualValue(dateTo));
    }

    final results = await query.get();
    return results.map((b) => b.id).toList();
  }

  SimpleSelectStatement<$BeitraegeTable, Beitrag> _applyBeitragFilters(
    SimpleSelectStatement<$BeitraegeTable, Beitrag> query,
    Map<String, String> filters,
  ) {
    for (final entry in filters.entries) {
      final field = entry.key;
      final value = entry.value.toLowerCase();

      if (value.isEmpty) continue;

      switch (field) {
        case 'status':
          query = query..where((b) => b.status.lower().contains(value));
          break;
      }
    }
    return query;
  }

  SimpleSelectStatement<$BeitraegeTable, Beitrag> _applyBeitragSorts(
    SimpleSelectStatement<$BeitraegeTable, Beitrag> query,
    List<SortColumnConfig> sorts,
  ) {
    final activeSorts = sorts.where((s) => s.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (activeSorts.isEmpty) return query;

    final orderings = activeSorts.map((sort) {
      switch (sort.field) {
        case 'datum':
          return (b) => OrderingTerm(
            expression: b.datum,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        case 'status':
          return (b) => OrderingTerm(
            expression: b.status,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        default:
          return (b) => OrderingTerm(expression: b.id);
      }
    }).toList();

    query = query..orderBy(orderings);
    return query;
  }

  // ── Leistungen ──────────────────────────────────────────────────────────

  Future<ExportDataTable> _fetchLeistungenData(
    DataGridMetaState metaState,
    bool includeAllColumns,
  ) async {
    var query = _db.select(_db.leistung);
    query = _applyLeistungFilters(query, metaState.activeFilters);
    query = _applyLeistungSorts(query, metaState.activeSorts);

    final results = await query.get();

    final columnsToInclude = _getColumnsToInclude(metaState, includeAllColumns);
    final headers = columnsToInclude.map((c) => c.title as String).toList();
    final rows = results
        .map((leistung) {
          return columnsToInclude
              .map((config) {
                final rawValue = config.valueExtractor(leistung);
                if (config.formatter != null) {
                  return config.formatter!(rawValue) as String;
                }
                return rawValue?.toString() ?? '';
              })
              .toList()
              .cast<String>();
        })
        .toList()
        .cast<List<String>>();

    return ExportDataTable(
      title: 'Leistungen',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<ExportDataTable> _fetchSingleLeistung(
    int itemId,
    DataGridMetaState metaState,
  ) async {
    final leistung = await (_db.select(
      _db.leistung,
    )..where((l) => l.id.equals(itemId))).getSingleOrNull();

    if (leistung == null) {
      return ExportDataTable(
        title: 'Leistung - Detail',
        headers: [],
        rows: [],
        exportedAt: DateTime.now(),
      );
    }

    final columnsToInclude = metaState.allColumns;
    final headers = columnsToInclude.map((c) => c.title).toList();
    final rows = [
      columnsToInclude.map((config) {
        final rawValue = config.valueExtractor(leistung);
        if (config.formatter != null) return config.formatter!(rawValue);
        return rawValue?.toString() ?? '';
      }).toList(),
    ];

    return ExportDataTable(
      title: 'Leistung - Detail',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<List<int>> _fetchLeistungIds(DataGridMetaState metaState) async {
    var query = _db.select(_db.leistung);
    query = _applyLeistungFilters(query, metaState.activeFilters);
    query = _applyLeistungSorts(query, metaState.activeSorts);

    final results = await query.get();
    return results.map((l) => l.id).toList();
  }

  SimpleSelectStatement<$LeistungTable, LeistungItem> _applyLeistungFilters(
    SimpleSelectStatement<$LeistungTable, LeistungItem> query,
    Map<String, String> filters,
  ) {
    for (final entry in filters.entries) {
      final field = entry.key;
      final value = entry.value.toLowerCase();

      if (value.isEmpty) continue;

      switch (field) {
        case 'name':
          query = query..where((l) => l.name.lower().contains(value));
          break;
      }
    }
    return query;
  }

  SimpleSelectStatement<$LeistungTable, LeistungItem> _applyLeistungSorts(
    SimpleSelectStatement<$LeistungTable, LeistungItem> query,
    List<SortColumnConfig> sorts,
  ) {
    final activeSorts = sorts.where((s) => s.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (activeSorts.isEmpty) return query;

    final orderings = activeSorts.map((sort) {
      switch (sort.field) {
        case 'name':
          return (l) => OrderingTerm(
            expression: l.name,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        default:
          return (l) => OrderingTerm(expression: l.id);
      }
    }).toList();

    query = query..orderBy(orderings);
    return query;
  }

  // ── Waren ───────────────────────────────────────────────────────────────

  Future<ExportDataTable> _fetchWarenData(
    DataGridMetaState metaState,
    bool includeAllColumns,
  ) async {
    var query = _db.select(_db.waren);
    query = _applyWareFilters(query, metaState.activeFilters);
    query = _applyWareSorts(query, metaState.activeSorts);

    final results = await query.get();

    final columnsToInclude = _getColumnsToInclude(metaState, includeAllColumns);
    final headers = columnsToInclude.map((c) => c.title as String).toList();
    final rows = results
        .map((ware) {
          return columnsToInclude
              .map((config) {
                final rawValue = config.valueExtractor(ware);
                if (config.formatter != null) {
                  return config.formatter!(rawValue) as String;
                }
                return rawValue?.toString() ?? '';
              })
              .toList()
              .cast<String>();
        })
        .toList()
        .cast<List<String>>();

    return ExportDataTable(
      title: 'Waren',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<ExportDataTable> _fetchSingleWare(
    int itemId,
    DataGridMetaState metaState,
  ) async {
    final ware = await (_db.select(
      _db.waren,
    )..where((w) => w.id.equals(itemId))).getSingleOrNull();

    if (ware == null) {
      return ExportDataTable(
        title: 'Ware - Detail',
        headers: [],
        rows: [],
        exportedAt: DateTime.now(),
      );
    }

    final columnsToInclude = metaState.allColumns;
    final headers = columnsToInclude.map((c) => c.title).toList();
    final rows = [
      columnsToInclude.map((config) {
        final rawValue = config.valueExtractor(ware);
        if (config.formatter != null) return config.formatter!(rawValue);
        return rawValue?.toString() ?? '';
      }).toList(),
    ];

    return ExportDataTable(
      title: 'Ware - Detail',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }

  Future<List<int>> _fetchWareIds(DataGridMetaState metaState) async {
    var query = _db.select(_db.waren);
    query = _applyWareFilters(query, metaState.activeFilters);
    query = _applyWareSorts(query, metaState.activeSorts);

    final results = await query.get();
    return results.map((w) => w.id).toList();
  }

  SimpleSelectStatement<$WarenTable, WarenItem> _applyWareFilters(
    SimpleSelectStatement<$WarenTable, WarenItem> query,
    Map<String, String> filters,
  ) {
    for (final entry in filters.entries) {
      final field = entry.key;
      final value = entry.value.toLowerCase();

      if (value.isEmpty) continue;

      switch (field) {
        case 'bezeichnung':
          query = query..where((w) => w.bezeichnung.lower().contains(value));
          break;
        case 'kategorie':
          query = query..where((w) => w.kategorie.lower().contains(value));
          break;
      }
    }
    return query;
  }

  SimpleSelectStatement<$WarenTable, WarenItem> _applyWareSorts(
    SimpleSelectStatement<$WarenTable, WarenItem> query,
    List<SortColumnConfig> sorts,
  ) {
    final activeSorts = sorts.where((s) => s.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (activeSorts.isEmpty) return query;

    final orderings = activeSorts.map((sort) {
      switch (sort.field) {
        case 'bezeichnung':
          return (w) => OrderingTerm(
            expression: w.bezeichnung,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        case 'kategorie':
          return (w) => OrderingTerm(
            expression: w.kategorie,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          );
        default:
          return (w) => OrderingTerm(expression: w.id);
      }
    }).toList();

    query = query..orderBy(orderings);
    return query;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Determines which columns to include based on visibility settings.
  List<dynamic> _getColumnsToInclude(
    DataGridMetaState metaState,
    bool includeAllColumns,
  ) {
    if (includeAllColumns) {
      return metaState.allColumns;
    }
    return metaState.allColumns
        .where((c) => metaState.visibleColumns.contains(c.field))
        .toList();
  }
}
