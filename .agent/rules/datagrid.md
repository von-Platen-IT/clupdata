---
trigger: always_on
---

# AI Coding Agent — Configuration: Feature-Rich DataGrid System (Flutter)

> **Scope:** This document defines binding rules and implementation guidelines for all tabular
> data views in this Flutter project. The AI coding agent MUST follow these rules without
> deviation unless explicitly overridden by the developer.

---

## 1. Mandatory Package

| Rule | Detail |
|------|--------|
| **[MUST]** | All tabular UI uses **PlutoGrid** exclusively. |
| Package | `pluto_grid` — https://pub.dev/packages/pluto_grid |
| No alternatives | Do NOT use `DataTable`, `DataTable2`, `Table`, or any other grid widget. |

```yaml
# pubspec.yaml
dependencies:
  pluto_grid: ^8.0.0   # use latest stable
  intl: ^0.19.0
```

---

## 2. Architecture: Shared Base Class

### 2.1 Principle

All DataGrid screens share a **single reusable base class** `AppDataGrid`.  
Concrete tables (e.g. `MemberDataGrid`) configure the base class via parameters.  
No grid-specific logic is duplicated across screens.

### 2.2 Class Structure

```
AppDataGrid                          ← abstract base widget
│
├── Required parameters
│   ├── columns       : List<PlutoColumn>
│   ├── rows          : List<PlutoRow>
│   ├── toSearchString: (PlutoRow) → String
│   └── sortableColumns: List<SortColumnConfig>
│
├── Internal state
│   ├── _searchText   : String
│   ├── _activeFilters: Map<String, String>
│   ├── _sortPriority : List<SortColumnConfig>
│   └── _stateManager : PlutoGridStateManager
│
└── Concrete implementations
    ├── MemberDataGrid
    ├── ContractDataGrid
    └── ... (one per data entity)
```

### 2.3 `SortColumnConfig` Model

```dart
class SortColumnConfig {
  final String field;        // PlutoColumn field name
  final String label;        // Human-readable column label
  bool enabled;              // checkbox: include in sort
  bool ascending;            // sort direction
  int priority;              // order in sort chain (0 = highest)
}
```

### 2.4 Adaptation to Table Structure

The base class adapts **dynamically** to the column structure provided.  
Filter dialogs, sort dialogs, and search logic all derive from the passed
`columns` list — no hardcoded field names in the base class.

---

## 3. UI Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  [ 🔍  Suche...                          ]   [ ⇅ ]   [ ▼ ]     │
├──────────────────────────────────────────────────────────────────┤
│  Spaltenheader  │  Spaltenheader  │  Spaltenheader  │  ...      │
├──────────────────────────────────────────────────────────────────┤
│  Zelle          │  Zelle          │  Zelle          │  ...      │
│  ...            │  ...            │  ...            │  ...      │
└──────────────────────────────────────────────────────────────────┘
```

The toolbar (search field + buttons) sits in a `Row` directly above the
`PlutoGrid` widget inside a `Column`.

---

## 4. Feature: Full-Text Search

### 4.1 UI Element

- A `TextField` spanning the full available width minus the two icon buttons.
- Placeholder text: `"Suche..."` (or localized equivalent).
- Search icon (`Icons.search`) as prefix icon.
- Clear button (`Icons.clear`) appears as suffix icon when text is non-empty.

### 4.2 Behavior

- Filtering triggers on every keystroke (`onChanged`) — no confirm button needed.
- Case-insensitive substring match.
- The filtered row list is reapplied to PlutoGrid via `stateManager`.

### 4.3 `toSearchString` Contract

Each concrete table **must** implement `toSearchString(PlutoRow row) → String`.  
The returned string must contain all visible cell values, joined by a space,
already formatted as displayed (e.g. date as `"dd.MM.yyyy"`, enums as
human-readable labels).

```dart
// Example: MemberDataGrid
@override
String toSearchString(PlutoRow row) {
  return [
    row.cells['name']?.value,
    row.cells['email']?.value,
    row.cells['join_date']?.value,      // formatted: "15.03.2024"
    row.cells['contract_type']?.value,  // formatted: "Jahresvertrag"
  ].whereNotNull().join(' ').toLowerCase();
}
```

---

## 5. Feature: Column Header Sort (Single Column)

- Clicking a **column header** toggles ascending / descending sort on that column.
- This is the standard PlutoGrid `onSort` behaviour — enable it via
  `PlutoColumn(enableSorting: true, ...)`.
- Single-column header sort coexists with the multi-column sort dialog (Section 6).
  When the multi-sort dialog is applied it takes precedence and resets header sort state.

---

## 6. Feature: Multi-Column Sort Dialog

### 6.1 Trigger

A button in the toolbar with a **stylised funnel / filter icon**
(`Icons.filter_list` or a custom coffee-filter SVG icon).  
Tooltip: `"Sortierung konfigurieren"`.

### 6.2 Dialog: Sort Settings

Opens as a **modal bottom sheet or `AlertDialog`** with the following content:

```
┌─────────────────────────────────────────┐
│  Sortierung                         [X] │
├─────────────────────────────────────────┤
│  Ziehen Sie Spalten in die gewünschte   │
│  Reihenfolge. Aktivieren Sie per        │
│  Checkbox.                              │
│                                         │
│  ☑  ≡  Name                  [ ↑ | ↓ ] │
│  ☑  ≡  Beitrittsdatum        [ ↑ | ↓ ] │
│  ☐  ≡  Vertragsart           [ ↑ | ↓ ] │
│  ☐  ≡  Ort                   [ ↑ | ↓ ] │
│                                         │
│            [Abbrechen]  [Übernehmen]    │
└─────────────────────────────────────────┘
```

### 6.3 Interaction Rules

| Element | Behaviour |
|---------|-----------|
| **Drag handle** (`≡`) | User drags rows via mouse or touch to reorder sort priority. Implemented with Flutter `ReorderableListView`. |
| **Checkbox** | Toggles whether this column participates in the sort. Unchecked columns are ignored but retain their position. |
| **Direction toggle** `[ ↑ \| ↓ ]` | Switches between ascending and descending for that column. |
| **Übernehmen** | Applies the sort chain to the grid. PlutoGrid rows are sorted client-side in priority order. |
| **Abbrechen** | Closes dialog without changes. |

### 6.4 Sort Application Logic

```
Sort chain = sortableColumns
  .where((c) => c.enabled)
  .sortedBy((c) => c.priority);

rows.sort((a, b) {
  for (final col in sortChain) {
    final cmp = compare(a.cells[col.field], b.cells[col.field]);
    if (cmp != 0) return col.ascending ? cmp : -cmp;
  }
  return 0;
});
```

---

## 7. Feature: Column Filter Dialog

### 7.1 Trigger

A second button in the toolbar — icon: `Icons.tune` or `Icons.filter_alt`.  
Tooltip: `"Spaltenfilter"`.

### 7.2 Dialog: Filter Settings

Opens as a **modal dialog or side sheet** listing every column that has
`enableFilterMenuItem: true` set in its `PlutoColumn` definition.

```
┌──────────────────────────────────────────┐
│  Filter                              [X] │
├──────────────────────────────────────────┤
│  Name                                    │
│  [ Müller                            ▼ ] │
│                                          │
│  Vertragsart                             │
│  [ Jahresvertrag                     ▼ ] │
│                                          │
│  Ort                                     │
│  [                                   ▼ ] │
│                                          │
│         [Filter zurücksetzen]            │
│              [Anwenden]                  │
└──────────────────────────────────────────┘
```

### 7.3 Autocomplete Behaviour

Each column field is represented by an **`Autocomplete<String>` widget**:

- The options list is derived at runtime from **distinct values** already present
  in that column across all (unfiltered) rows.
- As the user types, the dropdown shows matching existing values.
- The user may also type a free value not in the list.
- Matching is case-insensitive substring.

### 7.4 Filter Application Logic

- Multiple column filters are combined with **AND** logic.
- Active filters are indicated on the filter button (e.g. badge with count).
- "Filter zurücksetzen" clears all column filter fields.
- Filters combine with the full-text search (Section 4) — both are applied
  simultaneously.

---

## 8. Localisation

| Concern | Implementation |
|---------|---------------|
| Date display format | `'dd.MM.yyyy'` in every `PlutoColumnType.date(format: 'dd.MM.yyyy')` |
| Date picker header | `headerFormat: 'MMMM yyyy'` |
| Intl initialisation | `await initializeDateFormatting('de_DE', null)` in `main()` before `runApp` |
| PlutoGrid UI strings | Passed via `PlutoGridConfiguration(localeText: PlutoGridLocaleText(...))` — all labels in German |

### Minimum German `PlutoGridLocaleText` keys to set:

```dart
const PlutoGridLocaleText(
  filterTitle: 'Filter',
  filterAllColumns: 'Alle Spalten',
  filterContains: 'Enthält',
  filterEquals: 'Ist gleich',
  filterStartsWith: 'Beginnt mit',
  filterEndsWith: 'Endet mit',
  filterGreaterThan: 'Größer als',
  filterGreaterThanOrEqualTo: 'Größer oder gleich',
  filterLessThan: 'Kleiner als',
  filterLessThanOrEqualTo: 'Kleiner oder gleich',
  columnMenuItem: 'Spaltenoptionen',
  setColumnsTitle: 'Spalten ein-/ausblenden',
  filterSelectAll: 'Alle auswählen',
  filterClearFilter: 'Filter löschen',
  // add further keys as required by the installed pluto_grid version
)
```

---

## 9. PlutoGrid Base Configuration

Every instantiation of `AppDataGrid` must apply the following
`PlutoGridConfiguration` as default:

```dart
PlutoGridConfiguration(
  style: PlutoGridStyleConfig(
    enableColumnBorderVertical: true,
    enableColumnBorderHorizontal: true,
    oddRowColor: Color(0xFFF9F9F9),
  ),
  columnFilter: PlutoGridColumnFilterConfig(
    filters: const [
      ...FilterHelper.defaultFilters,
    ],
  ),
  localeText: appGermanLocaleText, // defined once, reused everywhere
)
```

---

## 10. Naming & File Conventions

```
lib/
└── widgets/
    └── data_grid/
        ├── app_data_grid.dart          ← abstract base class + toolbar
        ├── sort_column_config.dart     ← SortColumnConfig model
        ├── sort_settings_dialog.dart   ← multi-sort modal dialog
        ├── filter_settings_dialog.dart ← column filter modal dialog
        └── app_data_grid_locale.dart   ← German PlutoGridLocaleText const
lib/
└── features/
    └── members/
        └── widgets/
            └── member_data_grid.dart   ← concrete implementation
```

---

## 11. Checklist for Every New DataGrid Screen

Before submitting code for a new table view, verify:

- [ ] Extends / uses `AppDataGrid` — no standalone PlutoGrid widget.
- [ ] `toSearchString` implemented and covers all displayed fields.
- [ ] `sortableColumns` list provided with human-readable labels.
- [ ] All date columns use `format: 'dd.MM.yyyy'`.
- [ ] `PlutoGridConfiguration` applied with `appGermanLocaleText`.
- [ ] Filter dialog autocomplete derives options from actual row data.
- [ ] Sort dialog uses `ReorderableListView` with checkbox + direction toggle.
- [ ] Toolbar buttons have tooltips in German.
- [ ] No other grid/table widget imported or used.

---

*Last updated: 2026-02-26 — Version 1.0*

