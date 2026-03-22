## **description: AI Agent Ruleset for Flutter DataGrid implementations trigger: "*data\_grid*.dart, pluto\_grid, table, grid, list view"**

# **SYSTEM DIRECTIVE: FLUTTER DATAGRID IMPLEMENTATION**

\[CONTEXT\]  
You are an expert Flutter AI coding assistant. Whenever the user requests a tabular data view, a data grid, or a table with filtering/sorting capabilities, you MUST adhere strictly to the following architectural, OOP, and implementation rules.  
Do not deviate from these rules unless explicitly instructed by the user. Prioritize Clean Code, strict typing (Dart), and optimal performance.

## **1\. TECHNOLOGY STACK & MANDATORY PACKAGES**

* **\[MUST\]** All tabular UI MUST use **PlutoGrid** exclusively.  
* **\[FORBIDDEN\]** Do NOT use DataTable, DataTable2, Table, or any other built-in grid widget.  
* **\[MUST\]** Use the intl package for all date formatting and localization.

dependencies:  
  pluto\_grid: ^8.0.0  
  intl: ^0.19.0

## **2\. CORE ARCHITECTURE & STATE MANAGEMENT**

### **2.1 Generic Base Class (AppDataGrid\<T\>)**

* **\[MUST\]** Implement a generic base class AppDataGrid\<T\> that encapsulates the PlutoGrid instance.  
* **\[MUST\]** Apply Separation of Concerns: The base class MUST NOT contain domain-specific logic. Concrete tables (e.g., MemberDataGrid) configure the base class via parameters.

### **2.2 Controller Pattern (Inbound / Headless API)**

* **\[MUST\]** Expose a DataGridController\<T\> to manage state (\_searchText, \_activeFilters, \_sortPriority).  
* **\[MUST\]** The controller MUST allow external classes to completely control the UI programmatically without user interaction (Headless Capability).

### **2.3 Persistence Delegation (Outbound / CRUD)**

* **\[MUST\]** The AppDataGrid\<T\> MUST NOT hardcode database queries (e.g., Drift or Firebase logic).  
* **\[MUST\]** All database persistence MUST be delegated to the parent widget via explicitly defined callbacks: onItemCreated, onItemUpdated, onItemDeleted.

## **3\. BIDIRECTIONAL JSON API & DATA I/O**

The widget MUST provide robust inbound (pull/control) and outbound (push/extract) interfaces for both list data and detail data using strictly structured JSON.

### **3.1 JSON Payload Contract**

Every JSON payload processed or emitted by the widget MUST follow this exact structure:  
{  
  "action": "OPTIONAL\_STRING (e.g., SET\_STATE, CREATE, UPDATE, DELETE)",  
  "metadata": {  
    "columns": \[...\],  
    "active\_sort": \[...\],  
    "active\_filters": \[...\]  
  },  
  "data": "PAYLOAD (Array of T for lists, Object T for details)"  
}

### **3.2 Outbound Data Extraction (Pull & Push)**

* **\[MUST\] Sync Pull:** The Controller MUST expose String getExportJson() and String getDetailJson(T item) allowing external code to fetch the CURRENTLY sorted/filtered data.  
* **\[MUST\] Event Push:** The widget MUST provide callbacks onListExportRequested(String json) and onDetailExportRequested(String json).  
* **\[MUST\] UI Integration:** Child widgets SHOULD implement "Print" or "Export" buttons (in toolbar or modal) that trigger these callbacks.

### **3.3 Inbound Programmatic Control**

* **\[MUST\] State Injection:** The Controller MUST provide void applyStateFromJson(String json) to programmatically overwrite the UI filters and sorting.  
* **\[MUST\] CRUD Injection:** The Controller MUST provide void executeCrudFromJson(String json). When called, it MUST execute the requested operation and trigger the corresponding onItem... persistence callback (see 2.3).

### **3.4 Text-File Import / Export**

* **\[MUST\]** The Controller MUST implement Future\<void\> exportToFile(String filePath) to dump the JSON payload to a local text file.  
* **\[MUST\]** The Controller MUST implement Future\<void\> importFromFile(String filePath) to load state/data from a code-level text file.

## **4\. UI LAYOUT & INTERACTION DESIGN**

### **4.1 Layout Structure**

The toolbar sits in a Row directly above the PlutoGrid widget inside a Column.  
\+------------------------------------------------------------------+  
|  \[ Search...                       \]   \[ Sort \]   \[ Filter \]     |  
\+------------------------------------------------------------------+  
|  Column Header  |  Column Header   |  Column Header   |  ...     |  
\+------------------------------------------------------------------+  
|  Cell           |  Cell            |  Cell            |  ...     |  
\+------------------------------------------------------------------+

### **4.2 Full-Text Search**

* **UI:** A TextField spanning width minus buttons. Prefix: Icons.search, Suffix: Icons.clear.  
* **Behavior:** Filtering triggers on every keystroke (onChanged). Case-insensitive substring match.  
* **Contract:** Concrete tables MUST implement String toSearchString(PlutoRow row) containing all visible cell values formatted exactly as displayed.

### **4.3 Click Interactions (Single vs. Double) & Focus Management**

* **Single Click:** Enters inline editing mode (ONLY IF enableEditingMode: true is set for that column).  
* **Double Click:** Opens the full modal Edit/Create dialog (detailModalBuilder) for that record.  
* **\[MUST\] State Conflict Resolution:** Inline editing MUST be automatically terminated/committed BEFORE the modal dialog opens.  
* **\[MUST\] Focus Delegation:** The grid MUST detect the clicked column and pass its columnId to the detailModalBuilder. The modal MUST use this to set the initial FocusNode to the corresponding input field.

### **4.4 Advanced Sorting Logic**

* **Header Sort:** Clicking a column header toggles standard single-column sort.  
* **Multi-Sort Dialog:** Triggered via Icons.filter\_list. Opens a modal containing a ReorderableListView (Drag handle, Checkbox for enabled/disabled, Direction toggle).  
* **\[MUST\] Priority:** When multi-sort is applied, it takes absolute precedence and resets the single header sort state.

### **4.5 Dynamic Column Filter Dialog**

* **Trigger:** Toolbar button (Icons.tune or Icons.filter\_alt).  
* **Behavior:** Modals listing all columns configured with enableFilterMenuItem: true.  
* **Input:** Must use Autocomplete\<String\>. Options MUST be derived dynamically at runtime from distinct values present in the UNFILTERED row data.  
* **Logic:** Multiple column filters combine with AND logic, and stack with the Full-Text Search.

## **5\. SCHEMA, CONFIGURATION & LOCALIZATION**

### **5.1 Column Visibility, Ordering & Styling (structur.md)**

* **\[MUST\]** The initial column order MUST match the Data Grid Konfiguration in the project's structur.md exactly.  
* **\[MUST\] Computed Columns:** Fields like nettopreis or alter MUST have enableEditingMode: false and enableSorting set according to structur.md.  
* **\[MUST\] Hidden Columns:** Internal IDs (e.g., Foreign Keys) MUST NOT appear in the columns list. Pass them securely inside PlutoRow.cells without a UI column.  
* **\[MUST\] Read-Only Sync:** If a grid column has enableEditingMode: false, its corresponding input field inside the modal dialog MUST be read-only/disabled.  
* **\[MUST\] Row Styling:** Support rowBgColorResolver: Color? Function(T item) for dynamic, data-driven row background colors.

### **5.2 Localization (Strict German)**

* **\[MUST\]** Call await initializeDateFormatting('de\_DE', null) in main().  
* **\[MUST\]** All date columns MUST use format: 'dd.MM.yyyy'. Date picker headers use MMMM yyyy.  
* **\[MUST\]** Provide a fully localized German PlutoGridLocaleText to the grid configuration.

### **5.3 Base Grid Configuration**

Every instance MUST apply this default styling:  
PlutoGridConfiguration(  
  style: PlutoGridStyleConfig(  
    enableColumnBorderVertical: true,  
    enableColumnBorderHorizontal: true,  
    oddRowColor: Color(0xFFF9F9F9),  
  ),  
  columnFilter: PlutoGridColumnFilterConfig(  
    filters: const \[...FilterHelper.defaultFilters\],  
  ),  
  localeText: appGermanLocaleText, // Defined centrally  
)

## **6\. PERFORMANCE & CLEAN CODE RULES**

* **\[MUST\] Row Mapping (useMemoized):** The conversion of List\<T\> to List\<PlutoRow\> MUST be wrapped in useMemoized(() \=\> ..., \[dependencies\]). It is strictly FORBIDDEN to map data directly inside the build() method.  
* **\[MUST\] Computed Fields:** Calculated values MUST be computed in the Riverpod provider or RowData mapping. NEVER compute them inside the DataGrid widget's build cycle.  
* **\[MUST\] Stream-Driven Data:** All data sources MUST be Drift .watch() streams wrapped in Riverpod StreamProvider. Manual polling is forbidden.  
* **\[MUST\] Selective Rebuilds:** Use ref.watch(provider.select(...)) in child widgets to prevent unnecessary UI renders.  
* **\[MUST\] Dart Documentation:** Use strict Dart doc comments (///) for all public classes and methods. Use bracket references \[variableName\] for IDE integration.

## **7\. NAMING & DIRECTORY CONVENTIONS**

lib/  
└── widgets/  
    └── data\_grid/  
        ├── app\_data\_grid.dart          \<- Base class, Toolbar, Controller (JSON/CRUD API)  
        ├── sort\_column\_config.dart     \<- Sort Model  
        ├── sort\_settings\_dialog.dart   \<- Multi-Sort Modal  
        ├── filter\_settings\_dialog.dart \<- Filter Modal  
        └── app\_data\_grid\_locale.dart   \<- German Locales  
lib/  
└── features/  
    └── \[entity\_name\]/  
        └── widgets/  
            └── \[entity\]\_data\_grid.dart \<- Concrete implementation

## **8\. REQUIRED AI CHECKLIST (Verify before generating code)**

* \[ \] Extends AppDataGrid (No standalone PlutoGrid implementations).  
* \[ \] toSearchString implemented and covers all visible fields.  
* \[ \] Controller implements all JSON Inbound/Outbound APIs (getExportJson, applyStateFromJson, executeCrudFromJson).  
* \[ \] Text File Import/Export methods are fully implemented.  
* \[ \] onItemCreated, onItemUpdated, onItemDeleted callbacks defined for DB persistence.  
* \[ \] Modal dialog receives focusedColumnId from double-click event.  
* \[ \] Inline-edit is correctly committed before modal dialog opens.  
* \[ \] Sort dialog uses ReorderableListView.  
* \[ \] Filter dialog autocomplete derives options from actual runtime row data.  
* \[ \] Column order matches structur.md exactly.  
* \[ \] Row mapping utilizes useMemoized.  
* \[ \] All public API surfaces are documented using ///.