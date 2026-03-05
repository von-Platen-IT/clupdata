# AI Coding Agent — Configuration: Generic DataMaintenanceUi (AppDataGrid)

> **Scope:** This document defines the binding rules, architecture, and implementation guidelines for tabular data administration views (Create, Read, Update, Delete + Remarks) in this Flutter project.
> The AI coding agent MUST follow these guidelines to ensure UI consistency and code reusability across all feature domains (e.g., Members, Contracts, Services).

---

## 1. Architectural Principle & Motivation

We use `pluto_grid` for all data tables. To ensure consistency and to encapsulate generic behaviors (search, filtering, sorting, layout), we use a custom base widget: **`AppDataGrid`**.
This widget integrates seamlessly with Flutter hooks, Riverpod, and the PlutoGrid ecosystem.

---

## 2. Core Components

### 2.1 `AppDataGrid` (The Generic UI)
Located in `lib/widgets/data_grid/app_data_grid.dart`.

**Key features:**
- Centralized `pluto_grid` initialization and styling.
- Extensible multi-column sort dialog and full text search via `toSearchString`.
- Triggers events via `onRowSelected(PlutoRow row)` and `onRowActivated(PlutoRow row, String fieldName)`.

### 2.2 `FeatureScreenScaffold` (The Screen Scaffold)
Located in `lib/common_widgets/feature_screen_scaffold.dart`.

Every Data Maintenance screen MUST be wrapped inside this Scaffold, which provides:
- The AppBar with "Neu" and contextual "Löschen" buttons.
- Standardized layout handling.

---

## 3. Data Flow & State Management (Riverpod + Freezed)

### 3.1 Step 1: The Domain Model (`RowData`)
Do not pass raw database entities (like Drift's `Mitglied`) directly to the table if they require complex joins, calculations, or formatting.
Instead, create a dedicated mapped representation using `freezed` (e.g., `MemberRowData` or `ContractRowData`).

```dart
@freezed
abstract class FeatureRowData with _$FeatureRowData {
  const factory FeatureRowData({
    required int id,
    required String name,
    DateTime? formattedDate,
    String? joinedRelationName,
  }) = _FeatureRowData;
}
```

### 3.2 Step 2: The Provider
Create a standard Riverpod `Provider` (not `StateNotifier` or `FutureProvider` if streaming) that maps the database streams into the Freezed representation.

```dart
final featureGridRowsProvider = Provider<AsyncValue<List<FeatureRowData>>>((ref) {
  final dataResult = ref.watch(_datasetStreamProvider);
  if (dataResult.isLoading) return const AsyncValue.loading();
  
  // Map raw data -> Freezed RowData models here
  final rows = dataResult.value!.map((d) => FeatureRowData(...)).toList();
  return AsyncValue.data(rows);
});
```

---

## 4. UI Layout Rules (The "Master-Detail" Screen)

Every Data Maintenance screen MUST follow this strict structural layout pattern using a `FeatureScreenScaffold`:

### 4.1 Screen Structure
```dart
return FeatureScreenScaffold(
  title: 'Titel',
  hasSelection: selectedRowId.value != null,
  onCreateNew: () => EditDialog.show(context),
  onDeleteSelection: () => _deleteLogic(),
  body: Column(
    children: [
      Expanded(
        child: /* AppDataGrid injected here */
      ),
      if (selectedRowId.value != null)
        _BemerkungDetailView(itemId: selectedRowId.value!),
    ],
  ),
);
```

**[CRITICAL LAYOUT RULE]:** The grid (`AppDataGrid`) MUST ALWAYS be wrapped in an `Expanded` widget so it claims all remaining vertical space. The optional remarks/details panel at the bottom (`_BemerkungDetailView`) takes ONLY the space it needs (`MainAxisSize.min`).

### 4.2 Handling Interaction
- **Single Click (`onRowSelected`)**: Stores the ID of the clicked row into a local `useState<int?>` to unfold the bottom Bemerkung panel and enable the "Löschen" button.
- **Double Click (`onRowActivated`)**: Fetches the **complete, full database entity** via a `Repository` using the ID and opens the `EditDialog`.

---

## 5. The "Bemerkung" (Remarks) Panel

Almost all entities in the database share a 1:1 or N:1 relation to the `bemerkung` table via a `bemerkung_id` foreign key.

### 5.1 Detail View (Bottom Panel)
When an item is selected, display its current remark in an embedded container at the very bottom of the window:
- Needs 2 text fields: `Bemerkung Titel` and `Bemerkung Text` (multiline).
- Needs a distinct `Speichern`-Button aligned to the `bottomRight`.
- **Must save changes without closing the context.** The UI updates seamlessly through Riverpod streams.

### 5.2 Edit Dialog (Double-Click view)
- Every Edit/Create dialog **must** also include the Bemerkung text fields at the very bottom of the scrolling form.
- The `MembersRepository` (or equivalent feature repo) must handle creating/updating the `Bemerkung` entry **and** writing the foreign-key back to the parent entity.

### 5.3 Helper Method Example (Repository level)
When writing a new feature repository, orient the save logic on this structure:
```dart
Future<void> saveFeatureRemark(int entityId, int? existingBemerkungId, String title, String text) async {
  // 1. Update or Insert the Bemerkung record returning the ID
  final newBemerkungId = await _saveBemerkungBaseLogic(existingBemerkungId, title, text);
  
  // 2. If it was a newly created remark, write the FK back into the parent entity.
  if (existingBemerkungId == null) {
      await (_db.update(_db.featureTable)..where((t) => t.id.equals(entityId)))
        .write(FeatureTableCompanion(bemerkungId: Value(newBemerkungId)));
  }
}
```

---

## 6. AI Agent Step-by-Step Implementation Guide

If asked to implement a new `DataMaintenanceUi` for a feature (e.g. `Contracts`), execute the following steps:

1. **Verify DB Schema**: Ensure the parent table has a `bemerkung_id` foreign key.
2. **Model**: Create a `*RowData` `freezed` class exposing what the table should show.
3. **Riverpod View-Model**: Write `*GridRowsProvider` returning `AsyncValue<List<*RowData>>`.
4. **Build UI Scaffold**: `FeatureScreenScaffold` -> Column -> Expanded(`AppDataGrid`) -> Conditional `_BemerkungDetailView`.
5. **Add Actions**: Map `onRowActivated` to `FeatureEditDialog.show(context)`.
6. **Implement Dialog**: Dialog consists of a `FocusTraversalGroup` > `AlertDialog`. It accepts `(isEditing ? 'Bearbeiten' : 'Neu')` and writes fields via Riverpod to the Repository. Include the dialog-closing `IconButton(Icons.close)` in the `title: Row(...)`.
7. **Testing**: Trigger `dart run build_runner build -d`, review layout logic. No complex graphical animations inside the DataGrid components.
