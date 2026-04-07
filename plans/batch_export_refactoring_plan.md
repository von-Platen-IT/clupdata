# Batch-Export Refactoring Plan - ClupData

**Erstellt:** 2026-04-07
**Status:** Entwurf zur Review
**Ziel:** Entkopplung des Export-Systems vom UI und Implementierung von Batch-Exporten

## Executive Summary

Dieser Plan beschreibt die Entkopplung des Export-Systems vom UI und die Implementierung eines Batch-Export-Features für die ClupData-Anwendung. Das Ziel ist es, PDF-Exporte unabhängig vom UI-Zustand durchzuführen und Batch-Exporte für mehrere Datensätze zu ermöglichen.

---

## Analyse der aktuellen Architektur

### Aktuelle Komponenten

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
├─────────────────────────────────────────────────────────────────┤
│ VpitDataGrid<T>                                                  │
│  ├─ DataGridController<T> (Filter, Sort, Search)                │
│  ├─ PlutoGridStateManager (UI State, Column Visibility)         │
│  └─ generateExportSnapshot() → ExportContextData                │
│                                                                   │
│ ListExportMenuButton                                             │
│  └─ Liest ExportCacheProvider (LIFO Stack von Generatoren)      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Export Pipeline                               │
├─────────────────────────────────────────────────────────────────┤
│ ExportContextData (Snapshot)                                     │
│  ├─ ExportDataTable (visible columns)                           │
│  ├─ ExportDataTable (all columns)                               │
│  ├─ activeFilters: Map<String, String>                          │
│  └─ activeSorts: List<String>                                   │
│                                                                   │
│ PdfExporter                                                      │
│  ├─ prepareExport(ExportContextData) → PdfExportData            │
│  └─ generateFromData(PdfExportData, PdfTemplate) → Uint8List    │
│                                                                   │
│ PdfTemplateRegistry                                              │
│  └─ getSuitableFor(isDetailView, entityType) → List<Template>   │
└─────────────────────────────────────────────────────────────────┘
```

### Identifizierte Kopplungen

| Kopplung | Problem | Auswirkung |
|----------|---------|------------|
| **UI → Daten** | `generateExportSnapshot()` extrahiert Daten aus `PlutoGridStateManager` und `DataGridController` | Export nur möglich wenn UI gerendert ist |
| **Spalten-Sichtbarkeit** | Wird aus `PlutoGridStateManager.refColumns` gelesen | Keine programmatische Kontrolle über exportierte Spalten |
| **Filter/Sort State** | Lebt in `DataGridController`, wird aber nicht persistent gespeichert | Batch-Export kann Filter nicht wiederverwenden |
| **Datenquelle** | Daten kommen aus `ctrl.filteredSortedItems` (In-Memory) | Keine direkte Datenbankabfrage möglich |

---

## Refactoring-Strategie

### Phase 1: Globale State-Verwaltung für UI-Metadaten

#### Ziel
Entkopplung der Export-Metadaten (Filter, Sortierung, Spalten-Sichtbarkeit) vom UI-State.

#### Neue Komponenten

##### 1.1 `DataGridMetaState` (Domain Model)

```dart
/// Immutable state object holding DataGrid metadata.
class DataGridMetaState {
  /// Entity type identifier (e.g., 'mitglied', 'rechnung')
  final String entityType;
  
  /// Active column filters (field → value)
  final Map<String, String> activeFilters;
  
  /// Active sort configurations
  final List<SortColumnConfig> activeSorts;
  
  /// List of visible column field names (in display order)
  final List<String> visibleColumns;
  
  /// Full list of available column configurations
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
  
  DataGridMetaState copyWith({...}) { ... }
}
```

##### 1.2 `DataGridMetaStateNotifier` (Riverpod Provider)

```dart
/// Global state manager for DataGrid metadata.
/// 
/// Stores metadata per entity type, allowing multiple grids to coexist
/// and enabling headless export access.
@riverpod
class DataGridMetaStateNotifier extends _$DataGridMetaStateNotifier {
  @override
  Map<String, DataGridMetaState> build() => {};
  
  /// Updates or creates metadata for a specific entity type.
  void updateMetaState(String entityType, DataGridMetaState state) {
    state = {...state, entityType: state};
  }
  
  /// Retrieves metadata for a specific entity type.
  DataGridMetaState? getMetaState(String entityType) {
    return state[entityType];
  }
  
  /// Updates only filters for an entity type.
  void updateFilters(String entityType, Map<String, String> filters) {
    final current = state[entityType];
    if (current != null) {
      state = {...state, entityType: current.copyWith(activeFilters: filters)};
    }
  }
  
  /// Updates only sorts for an entity type.
  void updateSorts(String entityType, List<SortColumnConfig> sorts) {
    final current = state[entityType];
    if (current != null) {
      state = {...state, entityType: current.copyWith(activeSorts: sorts)};
    }
  }
  
  /// Updates visible columns for an entity type.
  void updateVisibleColumns(String entityType, List<String> columns) {
    final current = state[entityType];
    if (current != null) {
      state = {...state, entityType: current.copyWith(visibleColumns: columns)};
    }
  }
}
```

##### 1.3 Integration in `VpitDataGrid`

```dart
// In VpitDataGrid.build()

// Sync controller state to global provider
useEffect(() {
  if (exportConfig == null) return null;
  
  final notifier = ref.read(dataGridMetaStateNotifierProvider.notifier);
  
  // Initial sync
  notifier.updateMetaState(
    exportConfig!.entityType,
    DataGridMetaState(
      entityType: exportConfig!.entityType,
      activeFilters: ctrl.activeFilters,
      activeSorts: ctrl.sortConfigs,
      visibleColumns: stateManager.value?.refColumns.map((c) => c.field).toList() ?? [],
      allColumns: columnConfigs,
      searchText: ctrl.searchText,
    ),
  );
  
  // Listen to controller changes
  void listener() {
    notifier.updateMetaState(
      exportConfig!.entityType,
      DataGridMetaState(
        entityType: exportConfig!.entityType,
        activeFilters: ctrl.activeFilters,
        activeSorts: ctrl.sortConfigs,
        visibleColumns: stateManager.value?.refColumns.map((c) => c.field).toList() ?? [],
        allColumns: columnConfigs,
        searchText: ctrl.searchText,
      ),
    );
  }
  
  ctrl.addListener(listener);
  return () => ctrl.removeListener(listener);
}, [ctrl, exportConfig]);
```

---

### Phase 2: Headless Data Fetching

#### Ziel
Direkte Datenbankabfragen mit angewendeten Filtern und Sortierungen, unabhängig vom UI.

#### Neue Komponenten

##### 2.1 `ExportDataRepository` (Generic Repository)

```dart
/// Generic repository for fetching data for export purposes.
/// 
/// Applies filters and sorts at the database level for efficiency.
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
    // Similar switch statement for single item fetching
    // ...
  }
  
  // Private methods for each entity type
  
  Future<ExportDataTable> _fetchMitgliederData(
    DataGridMetaState metaState,
    bool includeAllColumns,
  ) async {
    // Build query with filters
    var query = _db.select(_db.mitglieds);
    
    // Apply filters
    query = _applyFiltersToMitgliederQuery(query, metaState.activeFilters);
    
    // Apply sorts
    query = _applySortsToMitgliederQuery(query, metaState.activeSorts);
    
    // Execute query
    final results = await query.get();
    
    // Determine which columns to include
    final columnsToInclude = includeAllColumns
        ? metaState.allColumns
        : metaState.allColumns.where((c) => metaState.visibleColumns.contains(c.field)).toList();
    
    // Build ExportDataTable
    final headers = columnsToInclude.map((c) => c.title).toList();
    final rows = results.map((mitglied) {
      return columnsToInclude.map((config) {
        final rawValue = config.valueExtractor(mitglied);
        if (config.formatter != null) return config.formatter!(rawValue);
        return rawValue?.toString() ?? '';
      }).toList();
    }).toList();
    
    return ExportDataTable(
      title: 'Mitglieder',
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }
  
  SelectStatement<Mitglieds, Mitglied> _applyFiltersToMitgliederQuery(
    SelectStatement<Mitglieds, Mitglied> query,
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
        case 'email':
          query = query..where((m) => m.email.lower().contains(value));
          break;
        // Add more fields as needed
      }
    }
    return query;
  }
  
  SelectStatement<Mitglieds, Mitglied> _applySortsToMitgliederQuery(
    SelectStatement<Mitglieds, Mitglied> query,
    List<SortColumnConfig> sorts,
  ) {
    final activeSorts = sorts.where((s) => s.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    
    if (activeSorts.isEmpty) return query;
    
    query = query..orderBy(activeSorts.map((sort) {
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
        // Add more fields as needed
        default:
          return (m) => OrderingTerm(expression: m.id);
      }
    }).toList());
    
    return query;
  }
  
  // Similar methods for other entity types...
}
```

##### 2.2 Riverpod Provider

```dart
@riverpod
ExportDataRepository exportDataRepository(Ref ref) {
  return ExportDataRepository(ref.watch(appDatabaseProvider));
}
```

---

### Phase 3: Refactoring des PDF-Exporters

#### Ziel
Anpassung des `PdfExporter` zur Nutzung der neuen headless Datenquelle.

#### Änderungen

##### 3.1 Neue `PdfExporter` Methode

```dart
class PdfExporter {
  // Existing methods remain...
  
  /// Prepares export data from metadata state (headless mode).
  /// 
  /// This method fetches data directly from the database using the
  /// metadata state, completely bypassing the UI.
  static Future<PdfExportData> prepareExportFromMetaState(
    ExportDataRepository repository,
    DataGridMetaState metaState, {
    bool useAllColumns = false,
  }) async {
    final dataTable = await repository.fetchDataForExport(
      entityType: metaState.entityType,
      metaState: metaState,
      includeAllColumns: useAllColumns,
    );
    
    final pdfContext = PdfExportContext(
      title: _getTitleForEntityType(metaState.entityType),
      exportTimestamp: DateTime.now(),
      activeFilters: metaState.activeFilters,
      activeSorts: metaState.activeSorts.where((s) => s.enabled).map((s) => 
        '${s.label} (${s.ascending ? "aufsteigend" : "absteigend"})'
      ).toList(),
      isDetailView: false,
      entityName: metaState.entityType,
    );
    
    return PdfExportData(
      dataTable: dataTable,
      context: pdfContext,
      isDetailView: false,
      entityType: metaState.entityType,
      detectedEntityType: _detectEntityType(metaState.entityType),
    );
  }
  
  /// Prepares export data for a single item (detail view, headless mode).
  static Future<PdfExportData> prepareDetailExportFromMetaState(
    ExportDataRepository repository,
    DataGridMetaState metaState,
    int itemId,
  ) async {
    final dataTable = await repository.fetchSingleItemForExport(
      entityType: metaState.entityType,
      itemId: itemId,
      metaState: metaState,
    );
    
    final pdfContext = PdfExportContext(
      title: '${_getTitleForEntityType(metaState.entityType)} - Detail',
      exportTimestamp: DateTime.now(),
      activeFilters: {},
      activeSorts: [],
      isDetailView: true,
      entityName: metaState.entityType,
    );
    
    return PdfExportData(
      dataTable: dataTable,
      context: pdfContext,
      isDetailView: true,
      entityType: metaState.entityType,
      detectedEntityType: _detectEntityType(metaState.entityType),
    );
  }
  
  static String _getTitleForEntityType(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'mitglied': return 'Mitglieder';
      case 'rechnung': return 'Rechnungen';
      case 'beitrag': return 'Beiträge';
      case 'leistung': return 'Leistungen';
      case 'ware': return 'Waren';
      default: return entityType;
    }
  }
}
```

##### 3.2 Anpassung `ListExportMenuButton`

```dart
// In _handleSelection method

// Option 1: Use existing UI snapshot (backward compatible)
final snapshotGenerator = ref.read(exportCacheProvider);
if (snapshotGenerator != null) {
  final contextData = snapshotGenerator();
  if (contextData != null) {
    // Existing flow...
  }
}

// Option 2: Use headless mode (new approach)
final metaState = ref.read(dataGridMetaStateNotifierProvider)[config.entityType];
if (metaState != null) {
  final repository = ref.read(exportDataRepositoryProvider);
  final exportData = await PdfExporter.prepareExportFromMetaState(
    repository,
    metaState,
    useAllColumns: useFullTable,
  );
  // Continue with PDF generation...
}
```

---

### Phase 4: Batch-Export-Funktion

#### Ziel
Ermöglichung von Batch-Exporten für mehrere Datensätze ohne UI-Interaktion.

#### Neue Komponenten

##### 4.1 `BatchExportConfig`

```dart
/// Configuration for batch export operations.
class BatchExportConfig {
  /// Entity type to export
  final String entityType;
  
  /// Optional list of specific item IDs to export (null = all filtered items)
  final List<int>? itemIds;
  
  /// Metadata state to use for filtering/sorting
  final DataGridMetaState metaState;
  
  /// Template key to use for all exports
  final String? templateKey;
  
  /// Output directory for generated PDFs
  final String outputDirectory;
  
  /// Filename pattern (supports placeholders: {id}, {name}, {date})
  final String filenamePattern;
  
  /// Whether to combine all PDFs into a single file
  final bool combineIntoSinglePdf;
  
  const BatchExportConfig({
    required this.entityType,
    this.itemIds,
    required this.metaState,
    this.templateKey,
    required this.outputDirectory,
    this.filenamePattern = '{entityType}_{id}_{date}.pdf',
    this.combineIntoSinglePdf = false,
  });
}
```

##### 4.2 `BatchPdfExporter`

```dart
/// Service for batch PDF export operations.
class BatchPdfExporter {
  final ExportDataRepository _repository;
  
  BatchPdfExporter(this._repository);
  
  /// Executes a batch export operation.
  /// 
  /// Returns a [BatchExportResult] with statistics and file paths.
  Future<BatchExportResult> executeBatchExport(
    BatchExportConfig config, {
    void Function(int current, int total)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final generatedFiles = <String>[];
    final errors = <BatchExportError>[];
    
    // Determine which items to export
    final itemIds = await _getItemIdsForExport(config);
    final total = itemIds.length;
    
    // Select template
    final template = config.templateKey != null
        ? PdfTemplateRegistry.get(config.templateKey!)
        : PdfTemplateRegistry.getDefaultFor(
            isDetailView: true,
            entityType: config.entityType,
          );
    
    if (template == null) {
      throw ArgumentError('No suitable template found for ${config.entityType}');
    }
    
    // Ensure output directory exists
    final outputDir = Directory(config.outputDirectory);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    // Export each item
    for (var i = 0; i < itemIds.length; i++) {
      final itemId = itemIds[i];
      onProgress?.call(i + 1, total);
      
      try {
        // Fetch data for this item
        final exportData = await PdfExporter.prepareDetailExportFromMetaState(
          _repository,
          config.metaState,
          itemId,
        );
        
        // Generate PDF
        final pdfBytes = await PdfExporter.generateFromData(exportData, template);
        
        // Generate filename
        final filename = await _generateFilename(
          config.filenamePattern,
          config.entityType,
          itemId,
          exportData,
        );
        
        // Save to file
        final filePath = '${outputDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        
        generatedFiles.add(filePath);
      } catch (e, stackTrace) {
        errors.add(BatchExportError(
          itemId: itemId,
          error: e.toString(),
          stackTrace: stackTrace.toString(),
        ));
      }
    }
    
    // Optionally combine into single PDF
    String? combinedFilePath;
    if (config.combineIntoSinglePdf && generatedFiles.isNotEmpty) {
      combinedFilePath = await _combinePdfs(
        generatedFiles,
        '${outputDir.path}/${config.entityType}_batch_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
    
    return BatchExportResult(
      totalItems: total,
      successCount: generatedFiles.length,
      errorCount: errors.length,
      generatedFiles: generatedFiles,
      combinedFilePath: combinedFilePath,
      errors: errors,
      duration: DateTime.now().difference(startTime),
    );
  }
  
  /// Determines which item IDs to export based on config.
  Future<List<int>> _getItemIdsForExport(BatchExportConfig config) async {
    if (config.itemIds != null) {
      return config.itemIds!;
    }
    
    // Fetch all items matching the current filters
    final dataTable = await _repository.fetchDataForExport(
      entityType: config.entityType,
      metaState: config.metaState,
      includeAllColumns: false,
    );
    
    // Extract IDs from the data (assumes first column or specific ID column)
    // This is a simplified approach; in reality, you'd need to fetch actual entity objects
    // For now, we'll need to modify fetchDataForExport to optionally return IDs
    throw UnimplementedError('Need to implement ID extraction from filtered data');
  }
  
  Future<String> _generateFilename(
    String pattern,
    String entityType,
    int itemId,
    PdfExportData exportData,
  ) async {
    final date = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    
    var filename = pattern
        .replaceAll('{entityType}', entityType)
        .replaceAll('{id}', itemId.toString())
        .replaceAll('{date}', date);
    
    // Extract name from first row if available
    if (exportData.dataTable.rows.isNotEmpty) {
      final firstRow = exportData.dataTable.rows.first;
      if (firstRow.isNotEmpty) {
        final name = firstRow.first.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        filename = filename.replaceAll('{name}', name);
      }
    }
    
    return filename;
  }
  
  /// Combines multiple PDF files into a single PDF.
  Future<String> _combinePdfs(List<String> pdfPaths, String outputPath) async {
    // This would require a PDF merging library
    // For now, placeholder implementation
    throw UnimplementedError('PDF combining not yet implemented');
  }
}
```

##### 4.3 Result Classes

```dart
class BatchExportResult {
  final int totalItems;
  final int successCount;
  final int errorCount;
  final List<String> generatedFiles;
  final String? combinedFilePath;
  final List<BatchExportError> errors;
  final Duration duration;
  
  const BatchExportResult({
    required this.totalItems,
    required this.successCount,
    required this.errorCount,
    required this.generatedFiles,
    this.combinedFilePath,
    required this.errors,
    required this.duration,
  });
  
  bool get hasErrors => errorCount > 0;
  double get successRate => totalItems > 0 ? successCount / totalItems : 0.0;
}

class BatchExportError {
  final int itemId;
  final String error;
  final String stackTrace;
  
  const BatchExportError({
    required this.itemId,
    required this.error,
    required this.stackTrace,
  });
}
```

##### 4.4 Riverpod Provider

```dart
@riverpod
BatchPdfExporter batchPdfExporter(Ref ref) {
  return BatchPdfExporter(ref.watch(exportDataRepositoryProvider));
}
```

##### 4.5 UI Integration (Optional)

```dart
/// Dialog for configuring and executing batch exports.
class BatchExportDialog extends ConsumerStatefulWidget {
  final String entityType;
  
  const BatchExportDialog({super.key, required this.entityType});
  
  @override
  ConsumerState<BatchExportDialog> createState() => _BatchExportDialogState();
}

class _BatchExportDialogState extends ConsumerState<BatchExportDialog> {
  bool _isExporting = false;
  int _currentItem = 0;
  int _totalItems = 0;
  BatchExportResult? _result;
  
  Future<void> _startBatchExport() async {
    setState(() {
      _isExporting = true;
      _currentItem = 0;
      _totalItems = 0;
    });
    
    final metaState = ref.read(dataGridMetaStateNotifierProvider)[widget.entityType];
    if (metaState == null) {
      // Handle error
      return;
    }
    
    final config = BatchExportConfig(
      entityType: widget.entityType,
      metaState: metaState,
      outputDirectory: '/path/to/exports', // TODO: Let user choose
      filenamePattern: '{entityType}_{id}_{name}.pdf',
      combineIntoSinglePdf: false,
    );
    
    final exporter = ref.read(batchPdfExporterProvider);
    
    try {
      final result = await exporter.executeBatchExport(
        config,
        onProgress: (current, total) {
          setState(() {
            _currentItem = current;
            _totalItems = total;
          });
        },
      );
      
      setState(() {
        _result = result;
        _isExporting = false;
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      // Handle error
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Batch-Export'),
      content: _isExporting
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Exportiere $_currentItem von $_totalItems...'),
              ],
            )
          : _result != null
              ? _buildResultView()
              : _buildConfigView(),
      actions: [
        if (!_isExporting)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        if (!_isExporting && _result == null)
          FilledButton(
            onPressed: _startBatchExport,
            child: const Text('Export starten'),
          ),
      ],
    );
  }
  
  Widget _buildConfigView() {
    // Configuration UI
    return Text('Batch-Export Konfiguration');
  }
  
  Widget _buildResultView() {
    // Results display
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Erfolgreich: ${_result!.successCount}'),
        Text('Fehler: ${_result!.errorCount}'),
        Text('Dauer: ${_result!.duration.inSeconds}s'),
      ],
    );
  }
}
```

---

## Implementierungsplan

### Prioritäten und Reihenfolge

| Phase | Aufgabe | Dateien | Aufwand | Abhängigkeiten |
|-------|---------|---------|---------|----------------|
| **1.1** | `DataGridMetaState` Model erstellen | `lib/core/models/data_grid_meta_state.dart` | 2h | - |
| **1.2** | `DataGridMetaStateNotifier` Provider | `lib/core/providers/data_grid_meta_state_provider.dart` | 3h | 1.1 |
| **1.3** | Integration in `VpitDataGrid` | `lib/widgets/data_grid_v2/vpit_data_grid.dart` | 4h | 1.2 |
| **1.4** | Tests für State Management | `test/core/providers/data_grid_meta_state_test.dart` | 2h | 1.2 |
| **2.1** | `ExportDataRepository` Basis | `lib/core/data/export_data_repository.dart` | 6h | 1.1 |
| **2.2** | Mitglieder-Implementierung | `lib/core/data/export_data_repository.dart` | 4h | 2.1 |
| **2.3** | Weitere Entity-Implementierungen | `lib/core/data/export_data_repository.dart` | 8h | 2.2 |
| **2.4** | Repository Tests | `test/core/data/export_data_repository_test.dart` | 4h | 2.3 |
| **3.1** | `PdfExporter` Erweiterung | `lib/widgets/data_grid_v2/export/pdf/pdf_exporter.dart` | 3h |