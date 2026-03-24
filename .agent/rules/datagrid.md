## **description: AI Agent Ruleset for Flutter DataGrid implementations trigger: "*data_grid*.dart, pluto_grid, table, grid, list view"**

# **SYSTEM DIRECTIVE: FLUTTER DATAGRID IMPLEMENTATION**

[CONTEXT]
You are an expert Flutter AI coding assistant. Whenever the user requests a tabular data view, a data grid, or a table with filtering/sorting capabilities, you MUST adhere strictly to the following architectural, OOP, and implementation rules.
Do not deviate from these rules unless explicitly instructed by the user. Prioritize Clean Code, strict typing (Dart), and optimal performance.

## **1. TECHNOLOGY STACK & MANDATORY PACKAGES**

* **[MUST]** All tabular UI MUST use **PlutoGrid** exclusively.
* **[FORBIDDEN]** Do NOT use DataTable, DataTable2, Table, or any other built-in grid widget.
* **[MUST]** Use the intl package for all date formatting and localization.

dependencies:
  pluto_grid: ^8.0.0
  intl: ^0.19.0

## **2. CORE ARCHITECTURE & STATE MANAGEMENT**

### **2.1 Generic Base Class (VpitDataGrid<T>)**

* **[MUST]** Implement a generic base class `VpitDataGrid<T>` that encapsulates the PlutoGrid instance.
* **[MUST]** Apply Separation of Concerns: The base class MUST NOT contain domain-specific logic. Concrete tables (e.g., `MemberDataGrid`) configure the base class via parameters.

### **2.2 Controller Pattern (Inbound / Headless API)**

* **[MUST]** Expose a `DataGridController<T>` to manage state (`_searchText`, `_activeFilters`, `_sortPriority`).
* **[MUST]** The controller MUST allow external classes to completely control the UI programmatically without user interaction (Headless Capability).
* **[MUST]** Controller extends `ChangeNotifier` and uses `notifyListeners()` for state updates.

### **2.3 Persistence Delegation (Outbound / CRUD)**

* **[MUST]** The `VpitDataGrid<T>` MUST NOT hardcode database queries (e.g., Drift or Firebase logic).
* **[MUST]** All database persistence MUST be delegated to the parent widget via explicitly defined callbacks: `onItemCreated`, `onItemUpdated`, `onItemDeleted`.

### **2.4 Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ AppDataGrid │  │ SortSettingsDlg │  │ FilterSettings  │ │
│  │    V2<T>    │  │                 │  │     Dialog      │ │
│  └──────┬──────┘  └─────────────────┘  └─────────────────┘ │
└─────────┼───────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Controller Layer                         │
│              DataGridController<T>                          │
│         (ChangeNotifier + Headless API)                     │
└─────────┬───────────────────────────────────────────────────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌────────┐  ┌─────────────┐
│PlutoGrid│  │ Repository  │
│         │  │   (Drift)   │
└─────────┘  └─────────────┘
```

## **3. BIDIRECTIONAL JSON API & DATA I/O**

The widget MUST provide robust inbound (pull/control) and outbound (push/extract) interfaces for both list data and detail data using strictly structured JSON.

### **3.1 JSON Payload Contract**

Every JSON payload processed or emitted by the widget MUST follow this exact structure:
```json
{
  "action": "OPTIONAL_STRING (e.g., SET_STATE, CREATE, UPDATE, DELETE)",
  "metadata": {
    "columns": [...],
    "active_sort": [...],
    "active_filters": [...]
  },
  "data": "PAYLOAD (Array of T for lists, Object T for details)"
}
```

### **3.2 Outbound Data Extraction (Pull & Push)**

* **[MUST] Sync Pull:** The Controller MUST expose `String getExportJson()` and `String getDetailJson(T item)` allowing external code to fetch the CURRENTLY sorted/filtered data.
* **[MUST] Event Push:** The widget MUST provide callbacks `onListExportRequested(String json)` and `onDetailExportRequested(String json)`.
* **[MUST] UI Integration:** Child widgets SHOULD implement "Print" or "Export" buttons (in toolbar or modal) that trigger these callbacks.

### **3.3 Inbound Programmatic Control**

* **[MUST] State Injection:** The Controller MUST provide `void applyStateFromJson(String json)` to programmatically overwrite the UI filters and sorting.
* **[MUST] CRUD Injection:** The Controller MUST provide `void executeCrudFromJson(String json)`. When called, it MUST execute the requested operation and trigger the corresponding `onItem...` persistence callback (see 2.3).

### **3.4 Text-File Import / Export**

* **[MUST]** The Controller MUST implement `Future<void> exportToFile(String filePath)` to dump the JSON payload to a local text file.
* **[MUST]** The Controller MUST implement `Future<void> importFromFile(String filePath)` to load state/data from a code-level text file.

## **4. UI LAYOUT & INTERACTION DESIGN**

### **4.1 Layout Structure**

The toolbar sits in a Row directly above the PlutoGrid widget inside a Column.
+------------------------------------------------------------------+
|  [ Search...                       ]   [ Sort 🔢]   [ Filter 🔢]  |
+------------------------------------------------------------------+
|  Column Header  |  Column Header   |  Column Header   |  ...     |
+------------------------------------------------------------------+
|  Cell           |  Cell            |  Cell            |  ...     |
+------------------------------------------------------------------+

Badges (🔢) indicate the count of active filters/sort configurations.

### **4.2 Full-Text Search**

* **UI:** A TextField spanning width minus buttons. Prefix: `Icons.search`, Suffix: `Icons.clear`.
* **Behavior:** Filtering triggers on every keystroke (onChanged). Case-insensitive substring match.
* **Contract:** Concrete tables MUST implement `String toSearchString(T item)` containing all visible cell values formatted exactly as displayed.

### **4.3 Click Interactions & Focus Management**

| Action | Behavior |
|--------|----------|
| **Single Click** | Selects the row |
| **Double Click** | Opens the full modal Edit/Create dialog (`detailModalBuilder`) for that record |
| **Enter Key** | Opens the detail dialog (accessibility support) |

* **[MUST] Focus Delegation:** The grid MUST detect the clicked column and pass its `columnId` to the `detailModalBuilder`. The modal MUST use this to set the initial `FocusNode` to the corresponding input field.

### **4.4 Advanced Sorting Logic**

* **Header Sort:** Clicking a column header toggles standard single-column sort.
* **Multi-Sort Dialog:** Triggered via toolbar button. Opens a modal containing a `ReorderableListView` (Drag handle, Checkbox for enabled/disabled, Direction toggle).
* **[MUST] Priority:** When multi-sort is applied, it takes absolute precedence and resets the single header sort state.

### **4.5 Dynamic Column Filter Dialog**

* **Trigger:** Toolbar button with badge showing active filter count.
* **Behavior:** Modals listing all columns configured with `filterable: true`.
* **Input:** Must use `Autocomplete<String>`. Options MUST be derived dynamically at runtime from distinct values present in the UNFILTERED row data.
* **Logic:** Multiple column filters combine with AND logic, and stack with the Full-Text Search.

## **5. SCHEMA, CONFIGURATION & LOCALIZATION**

### **5.1 Column Visibility, Ordering & Styling (structur.md)**

* **[MUST]** The initial column order MUST match the Data Grid Konfiguration in the project's `structur.md` exactly.
* **[MUST] Computed Columns:** Fields like `nettopreis` or `alter` MUST have `editable: false` and `sortable` set according to `structur.md`.
* **[MUST] Hidden Columns:** Internal IDs (e.g., Foreign Keys) MUST NOT appear in the columns list. Pass them securely inside `PlutoRow.cells` without a UI column.
* **[MUST] Read-Only Sync:** If a grid column has `editable: false`, its corresponding input field inside the modal dialog MUST be read-only/disabled.
* **[MUST] Row Styling:** Support `rowBgColorResolver: Color? Function(T item)` for dynamic, data-driven row background colors.

### **5.2 Localization (Strict German)**

* **[MUST]** Call `await initializeDateFormatting('de_DE', null)` in main().
* **[MUST]** All date columns MUST use format: `'dd.MM.yyyy'`. Date picker headers use `MMMM yyyy`.
* **[MUST]** Provide a fully localized German `PlutoGridLocaleText` to the grid configuration.

### **5.3 Base Grid Configuration**

Every instance MUST apply this default styling:
```dart
PlutoGridConfiguration(
  style: PlutoGridStyleConfig(
    enableColumnBorderVertical: true,
    enableColumnBorderHorizontal: true,
    oddRowColor: Color(0xFFF9F9F9),
  ),
  columnFilter: PlutoGridColumnFilterConfig(
    filters: const [...FilterHelper.defaultFilters],
  ),
  localeText: appGermanLocaleText, // Defined centrally
)
```

## **6. CONTROLLER API REFERENCE**

### **6.1 Constructor Parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `columnConfigs` | `List<DataGridColumnConfig<T>>` | ✅ | Column definitions |
| `toJson` | `Map<String, dynamic> Function(T)` | ✅ | Serialize item to JSON |
| `fromJson` | `T Function(Map<String, dynamic>)` | ✅ | Deserialize JSON to item |
| `toSearchString` | `String Function(T)` | ✅ | Extract searchable text |
| `onItemCreated` | `void Function(T)?` | ❌ | CRUD: Create callback |
| `onItemUpdated` | `void Function(T)?` | ❌ | CRUD: Update callback |
| `onItemDeleted` | `void Function(T)?` | ❌ | CRUD: Delete callback |

### **6.2 Getters**

| Getter | Type | Description |
|--------|------|-------------|
| `searchText` | `String` | Current search text |
| `activeFilters` | `Map<String, String>` | Active column filters (field → value) |
| `sortConfigs` | `List<SortColumnConfig>` | Sort configurations |
| `items` | `List<T>` | All raw data |
| `filteredSortedItems` | `List<T>` | Data after filter/search/sort |

### **6.3 Setters**

| Setter | Description |
|--------|-------------|
| `searchText = value` | Sets search text and triggers recompute |
| `activeFilters = value` | Sets filters and triggers recompute |
| `sortConfigs = value` | Sets sort order and triggers recompute |

### **6.4 Methods**

| Method | Signature | Description |
|--------|-----------|-------------|
| `updateItems` | `void updateItems(List<T> newItems)` | Updates raw data |
| `updateColumnConfigs` | `void updateColumnConfigs(List<DataGridColumnConfig<T>> configs)` | Updates column definitions at runtime |
| `getExportJson` | `String getExportJson()` | Exports filtered/sorted data as JSON |
| `getDetailJson` | `String getDetailJson(T item)` | Exports single item as JSON |
| `applyStateFromJson` | `void applyStateFromJson(String json)` | Sets filters/sort from JSON |
| `executeCrudFromJson` | `void executeCrudFromJson(String json)` | Executes CRUD from JSON (CREATE/UPDATE/DELETE) |
| `exportToFile` | `Future<void> exportToFile(String filePath)` | Saves JSON to file |
| `importFromFile` | `Future<void> importFromFile(String filePath)` | Loads state from file |

## **7. APPDATAGRIDV2 WIDGET PARAMETERS**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `items` | `List<T>` | ✅ | Data to display |
| `columnConfigs` | `List<DataGridColumnConfig<T>>` | ✅ | Column definitions |
| `toSearchString` | `String Function(T)` | ✅ | Search string extractor |
| `toJson` | `Map<String, dynamic> Function(T)` | ✅ | JSON serializer |
| `fromJson` | `T Function(Map<String, dynamic>)` | ✅ | JSON deserializer |
| `onItemCreated` | `void Function(T)?` | ❌ | CRUD: Create callback |
| `onItemUpdated` | `void Function(T)?` | ❌ | CRUD: Update callback |
| `onItemDeleted` | `void Function(T)?` | ❌ | CRUD: Delete callback |
| `detailModalBuilder` | `void Function(T, String)?` | ❌ | Opens edit dialog on double-click |
| `onListExportRequested` | `void Function(String)?` | ❌ | Called on export click |
| `onDetailExportRequested` | `void Function(String)?` | ❌ | Called on detail export |
| `rowBgColorResolver` | `Color? Function(T)?` | ❌ | Dynamic row background color |
| `onRowSelected` | `void Function(T?)?` | ❌ | Called when row selection changes |
| `controller` | `DataGridController<T>?` | ❌ | External controller (optional) |
| `initialSelectedId` | `int?` | ❌ | ID of initially selected row (navigation persistence) |

## **8. DATAGRIDCOLUMNCONFIG PARAMETERS**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `field` | `String` | required | Unique column ID |
| `title` | `String` | required | Displayed title |
| `type` | `PlutoColumnType` | required | Data type (text, number, date) |
| `valueExtractor` | `dynamic Function(T)` | required | Extracts value from item |
| `editable` | `bool` | `false` | Allow inline editing |
| `sortable` | `bool` | `true` | Allow sorting |
| `filterable` | `bool` | `true` | Allow filtering |
| `textAlign` | `PlutoColumnTextAlign` | `left` | Cell alignment |
| `titleTextAlign` | `PlutoColumnTextAlign` | `left` | Title alignment |
| `formatter` | `String Function(dynamic)?` | `null` | Formatting function |
| `renderer` | `Widget Function(PlutoColumnRendererContext)?` | `null` | Custom cell renderer |
| `minWidth` | `double?` | `null` | Minimum width |
| `width` | `double?` | `null` | Default width |

## **9. SORTCOLUMNCONFIG PROPERTIES**

| Property | Type | Description |
|----------|------|-------------|
| `field` | `String` | Column ID |
| `label` | `String` | Display label |
| `enabled` | `bool` | Is this sort active? |
| `ascending` | `bool` | `true` = ascending, `false` = descending |
| `priority` | `int` | Priority (0 = sort first) |

## **10. PERFORMANCE & CLEAN CODE RULES**

* **[MUST] Row Mapping (useMemoized):** The conversion of `List<T>` to `List<PlutoRow>` MUST be wrapped in `useMemoized(() => ..., [dependencies])`. It is strictly FORBIDDEN to map data directly inside the build() method.
* **[MUST] Computed Fields:** Calculated values MUST be computed in the Riverpod provider or RowData mapping. NEVER compute them inside the DataGrid widget's build cycle.
* **[MUST] Stream-Driven Data:** All data sources MUST be Drift `.watch()` streams wrapped in Riverpod StreamProvider. Manual polling is forbidden.
* **[MUST] Selective Rebuilds:** Use `ref.watch(provider.select(...))` in child widgets to prevent unnecessary UI renders.
* **[MUST] Dart Documentation:** Use strict Dart doc comments (`///`) for all public classes and methods. Use bracket references `[variableName]` for IDE integration.

## **11. NAMING & DIRECTORY CONVENTIONS**

```
lib/
└── widgets/
    └── data_grid_v2/
        ├── vpit_data_grid.dart       <- Base class, Toolbar, Controller (JSON/CRUD API)
        ├── data_grid_controller.dart   <- Controller implementation
        ├── data_grid_column_config.dart  <- Column configuration
        ├── sort_column_config.dart     <- Sort model
        ├── sort_settings_dialog.dart   <- Multi-Sort Modal
        ├── filter_settings_dialog.dart <- Filter Modal
        ├── json_payload.dart           <- JSON data structures
        └── data_grid_locale_de.dart    <- German locales
lib/
└── features/
    └── [entity_name]/
        └── widgets/
            └── [entity]_data_grid.dart <- Concrete implementation
```

## **12. REQUIRED AI CHECKLIST (Verify before generating code)**

* [ ] Extends `VpitDataGrid` (No standalone PlutoGrid implementations).
* [ ] `toSearchString` implemented and covers all visible fields.
* [ ] Controller implements all JSON Inbound/Outbound APIs (`getExportJson`, `applyStateFromJson`, `executeCrudFromJson`).
* [ ] Text File Import/Export methods are fully implemented.
* [ ] `onItemCreated`, `onItemUpdated`, `onItemDeleted` callbacks defined for DB persistence.
* [ ] Modal dialog receives `focusedColumnId` from double-click event.
* [ ] Sort dialog uses `ReorderableListView`.
* [ ] Filter dialog autocomplete derives options from actual runtime row data.
* [ ] Column order matches `structur.md` exactly.
* [ ] Row mapping utilizes `useMemoized`.
* [ ] All public API surfaces are documented using `///`.
* [ ] `onRowSelected` callback implemented if selection persistence needed.
* [ ] `initialSelectedId` parameter used for navigation persistence.
* [ ] Toolbar shows badges for active filters/sort count.
