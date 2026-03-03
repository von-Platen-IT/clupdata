# AI Coding Agent — Configuration: AppDataGrid & Edit Dialogs

> **Scope:** This document defines the binding rules for all modal edit dialogs that are triggered from tabular data views (`AppDataGrid`) within this Flutter project. The AI coding agent MUST follow these rules without deviation when generating or modifying edit dialogs and datagrids.

---

## 1. Mandatory Data Views

- **[MUST]** All tabular data in the application MUST be displayed using the `AppDataGrid` base component (built on top of `pluto_grid`). Do not use alternative table widgets for data lists.
- **[MUST]** Single-click on a cell: enters **inline editing mode** for that cell (only if the column has `enableEditingMode: true`). See `datagrid.md` Section 6.
- **[MUST]** Double-click on a row: **always** opens the modal Edit/Create dialog, committing any pending inline edit first.
- **[MUST]** Creating and editing complete records is handled via disconnected Modal Dialogs (`AlertDialog`). Search, Filter, Sort behaviors are defined in `datagrid.md`.

---

## 2. Architecture & Inheritance Strategy

To maximize reusability while allowing entity-specific customization (computed columns, specific column ordering, visibility), the DataGrid implementation MUST follow a strict inheritance and separation of concerns pattern.

### 2.1 The Generic Base Class (`AppDataGrid`)
The abstract base class is responsible for **generic UI and behavior only**. It knows nothing about the concrete data entities (Members, Goods, etc.).
- **Responsibilities:**
  - Rendering the `PlutoGrid` widget and the Toolbar (Search, Filter, Sort buttons).
  - Managing internal state for full-text search, multi-column sorting, and column filtering.
  - Handling single-click (inline editing trigger) and double-click (modal dialog trigger) events.
  - Providing the generic UI framework (colors, borders, localization).

### 2.2 The Concrete Child Classes (e.g., `MemberDataGrid`, `WarenDataGrid`)
For every data entity listed in `structur.md`, a specific concrete widget extends or wraps `AppDataGrid`. 
- **Responsibilities:**
  - **Data Fetching:** Watching the Riverpod Provider to fetch the `AsyncValue<List<FeatureRowData>>`.
  - **Column Definition:** Defining the `List<PlutoColumn>` based exactly on the `structur.md` configuration. This includes setting titles, types (text, date, number), and `enableEditingMode` (editable vs. read-only, e.g., for computed fields).
  - **Row Mapping:** Converting the `FeatureRowData` into `PlutoRow` objects.
  - **Search String:** Implementing the abstract `toSearchString` method by combining the entity's searchable text fields.
  - **Dialog Trigger:** Providing the `onRowDoubleTap` callback to open the entity-specific Modal Dialog (`FeatureEditDialog.show`), passing the clicked column name for focus management.
  
### 2.3 Mapping from `structur.md` to Implementation
When scaffold a new grid, the AI Agent MUST look at the `Data Grid Konfiguration` in `structur.md`:
- **Spalten (Columns):** The EXACT order of the listed columns in `structur.md` MUST be the order in the `columns` array.
- **Computed Fields:** Fields like `alter` (Mitglieder) or `nettopreis` (Waren/Leistungen) MUST be configured as `enableEditingMode: false` (ReadOnly).
- **Sort/Filter Flags:** Apply `enableSorting`, `enableFilterMenuItem` based on the `Sort:True Filter:True` flags in the schema.

---

## 3. Modal Dialog Requirements

Every edit/create dialog triggered from a DataGrid MUST comply with the following interaction and layout rules:

### 3.1 Dialog Shortcuts & Closure
- **[MUST] X-Button:** Every dialog must have a close button (`IconButton(Icons.close)`) in the top right corner of the `title` row.
- **[MUST] Cancel Button:** Every dialog must have an explicit "Abbrechen" (Cancel) `TextButton` in the `actions` area.
- **[MUST] Keybindings via CallbackShortcuts:** The dialog must wrap the `Focus`/`AlertDialog` tree with `CallbackShortcuts`.
  - Pressing `Escape` MUST close the dialog via `Navigator.of(context).pop()`.
  - Pressing `Enter` MUST trigger the save logic (unless currently saving/invalid).
- **[MUST] No Side Effects:** Closing the dialog via X, Abbrechen, or ESC must **never** save the data or leave the underlying state materially altered.

### 3.2 Save Confirmation (Status Message)
- **[MUST] Feedback:** When the user clicks "Speichern" (Save) and the repository completes the transaction successfully, the dialog closes AND a brief success message (e.g., via `ScaffoldMessenger.of(context).showSnackBar`) MUST be displayed in the application's status area/bottom.

### 3.3 Focus Management (Contextual Editing)
When a user double-clicks (`onRowDoubleTap`) a specific cell in the `AppDataGrid`:
- **[MUST] Parameter Passing:** The DataGrid implementation must identify the exact field/column that was clicked. This information (e.g., the `PlutoColumn` field name or a specific enum/focus node identifier) must be passed to the modal dialog constructor.
- **[MUST] Auto-Focus:** The modal dialog must evaluate this passed parameter and automatically set the keyboard focus (`FocusNode.requestFocus()`) to the corresponding input widget (TextField, Dropdown, etc.) responsible for that data field.
- **[MUST] Desktop First:** The dialog must be fully operable via keyboard (Tab and Shift+Tab) utilizing `FocusTraversalGroup` and `NumericFocusOrder`.

### 3.4 Deletion Strategy
- **[MUST] Delete Button:** If editing an existing record (i.e. ID is not null), the dialog `actions` must feature a "Löschen" (Delete) button, clearly indicated via a red icon/text color.
- **[MUST] Confirmation Dialog:** Clicking the delete button MUST open a secondary `AlertDialog` asking the user: "Möchten Sie diesen Datensatz unwiderruflich löschen?". Only if the user confirms will the repository sequence trigger. Do not perform destructive events on a single click.

---

## 3. Implementation Blueprint Example

When implementing the dialog trigger from `AppDataGrid`:

```dart
// In a concrete AppDataGrid implementation:
onRowDoubleTap: (event) {
  // event.cell provides the exact cell that was clicked
  final clickedFieldName = event.cell.column.field;
  
  FeatureEditDialog.show(
    context, 
    details: event.row.cells['id'].value, 
    initialFocusField: clickedFieldName, // Implement targeted focus
  );
}
```

In the target Dialog:

```dart
// Receive initialFocusField
final focusNodeName = useFocusNode();
final focusNodeDate = useFocusNode();

useEffect(() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (initialFocusField == 'name') {
      focusNodeName.requestFocus();
    } else if (initialFocusField == 'date') {
      focusNodeDate.requestFocus();
    }
  });
  return null;
}, []);

// Ensure UI provides the visual close options
AlertDialog(
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text('Bearbeiten'),
      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
    ],
  ),
  actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
    ElevatedButton(
      onPressed: () async {
        await repo.save(...);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erfolgreich gespeichert')));
        }
      },
      child: const Text('Speichern'),
    ),
  ],
)
```

---
*Status: Active*
*Applies to: All DataMaintenanceUi / AppDataGrid modal counterparts*
