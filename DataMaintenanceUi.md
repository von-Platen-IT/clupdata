# AI Coding Agent — Configuration: Generic DataMaintenanceUi (AppDataTable)

> **Scope:** This document defines the binding rules, architecture, and implementation guidelines for tabular data administration views (Create, Read, Update, Delete + Remarks) in this Flutter project.
> The AI coding agent MUST follow these guidelines to ensure UI consistency and code reusability across all feature domains (e.g., Members, Contracts, Services).

---

## 1. Architectural Principle & Motivation

We **DO NOT** use complex third-party grid packages (like `pluto_grid`) for data tables due to performance overhead, state management issues, and null-check crashes.

Instead, we use a custom, highly optimized generic widget: **`AppDataTable<T>`**.
This widget is strictly object-oriented, strongly typed, and integrates seamlessly with Flutter hooks and Riverpod.

---

## 2. Core Components

### 2.1 `AppDataTable<T>` (The Generic UI)
Located in `lib/widgets/data_grid/app_data_table.dart`.

**Key features:**
- Stripped of Material animation overhead (uses `GestureDetector` instead of `InkWell`).
- Handles sorting internally.
- Handles text-based searching internally (if `searchFilter` is provided).
- Triggers events via `onRowSelected(T item)` and `onRowDoubleTap(T item)`.

### 2.2 `DataTableColumn<T>`
Located in `lib/widgets/data_grid/data_table_column.dart`.

Every column in the table is mapped through this model:
```dart
DataTableColumn<T>(
  label: 'Spaltenname',
  valueExtractor: (item) => item.textEigenschaft,
  sortExtractor: (item) => item.datumOderZahl, // Optional: Für sauberes Sortieren von z.B. Strings als DateTime
  sortable: true,
  flex: 2, // Optional: Relative Breite, falls fixedWidth nicht genutzt wird
  fixedWidth: 70, // Optional: Strikte Pixelbreite, für z.B. Icons
  cellBuilder: (item) => Widget, // Optional: Custom Rendering
)
```

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

Every Data Maintenance screen MUST follow this strict structural layout pattern using a `Scaffold` and a `Column`:

### 4.1 Screen Structure
```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Titel'),
    actions: [ /* "Neu" Button triggers EditDialog */ ],
  ),
  body: Column(
    children: [
      Expanded(
        child: /* AppDataTable<T> injected here */
      ),
      if (selectedItemId.value != null)
        _BemerkungDetailView(itemId: selectedItemId.value!),
    ],
  ),
)
```

**[CRITICAL LAYOUT RULE]:** The table (`AppDataTable`) MUST ALWAYS be wrapped in an `Expanded` widget so it claims all remaining vertical space. The optional remarks/details panel at the bottom (`_BemerkungDetailView`) takes ONLY the space it needs (`MainAxisSize.min`).

### 4.2 Handling Interaction
- **Single Click (`onRowSelected`)**: Stores the ID of the clicked row into a local `useState<int?>` to unfold the bottom Bemerkung panel.
- **Double Click (`onRowDoubleTap`)**: Fetches the **complete, full database entity** via a `Repository` using the ID and opens the `EditDialog`.

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
4. **Build UI Scaffold**: Scaffold -> Column -> Expanded(`AppDataTable`) -> Conditional `_BemerkungDetailView`.
5. **Add Actions**: Map `onRowDoubleTap` to `FeatureEditDialog.show(context)`.
6. **Implement Dialog**: Dialog consists of a `FocusTraversalGroup` > `AlertDialog`. It accepts `(isEditing ? 'Bearbeiten' : 'Neu')` and writes fields via Riverpod to the Repository. Include the dialog-closing `IconButton(Icons.close)` in the `title: Row(...)`.
7. **Testing**: Trigger `dart run build_runner build -d`, review layout logic. No complex graphical animations inside the DataGrid components.
