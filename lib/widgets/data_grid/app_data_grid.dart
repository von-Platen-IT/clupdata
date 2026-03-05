import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:gap/gap.dart';

import 'app_data_grid_locale.dart';
import 'filter_settings_dialog.dart';
import 'sort_column_config.dart';
import 'sort_settings_dialog.dart';

/// The abstract base class for all tabular data screens in the application.
/// Provides common functionality: full-text search, multi-column sort, column
/// filter, an optional "Neu" button, and the base PlutoGrid setup.
///
/// Keyboard navigation:
/// - Arrow keys navigate between cells (PlutoGrid native behaviour).
/// - [LogicalKeyboardKey.enter] opens the entity-specific modal dialog for the
///   currently focused row/cell by invoking [onRowActivated].
class AppDataGrid extends HookWidget {
  /// The list of [PlutoRow]s to display. Data objects are mapped to [PlutoRow]
  /// inside the child widget via [useMemoized].
  final List<PlutoRow> rows;

  /// The columns defined according to structur.md rules.
  final List<PlutoColumn> columns;

  /// The columns that are available in the multi-sort dialog.
  final List<SortColumnConfig> sortableColumns;

  /// Called per row to build the full-text-search string.
  /// Must return all visible cell values joined by space, lowercased.
  final String Function(PlutoRow row) toSearchString;

  /// Optional callback for single-click row selection.
  final void Function(PlutoRow row)? onRowSelected;

  /// Triggered when a row is activated — either by double-click or by pressing
  /// [LogicalKeyboardKey.enter] while the row is focused.
  ///
  /// [row] is the activated [PlutoRow]; [fieldName] is the column field of the
  /// cell that was focused, used to set initial focus in the modal dialog.
  final void Function(PlutoRow row, String fieldName) onRowActivated;

  /// Optional callback to open the "create new record" modal dialog.
  /// When provided, a "Neu" [FilledButton] is added to the toolbar.
  final VoidCallback? onCreateNew;

  const AppDataGrid({
    super.key,
    required this.rows,
    required this.columns,
    required this.sortableColumns,
    required this.toSearchString,
    this.onRowSelected,
    required this.onRowActivated,
    this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    // PlutoGrid state manager, assigned in onLoaded
    final stateManager = useState<PlutoGridStateManager?>(null);

    // Search & filter state
    final searchController = useTextEditingController();
    final searchText = useState<String>('');
    final activeFilters = useState<Map<String, String>>({});
    final activeSortConfigs = useState<List<SortColumnConfig>>(sortableColumns);

    // Apply all filters, search, and sort chain to the grid whenever any
    // of the dependencies change, including the initial data load.
    useEffect(() {
      final sm = stateManager.value;
      if (sm == null) return null;

      // 1. Start from the full unfiltered dataset
      var filteredRows = List<PlutoRow>.from(rows);

      // 2. Apply column filters (AND-combined)
      if (activeFilters.value.isNotEmpty) {
        filteredRows = filteredRows.where((row) {
          for (final entry in activeFilters.value.entries) {
            final filterValue = entry.value.toLowerCase();
            final cellValue =
                row.cells[entry.key]?.value?.toString().toLowerCase() ?? '';
            if (!cellValue.contains(filterValue)) return false;
          }
          return true;
        }).toList();
      }

      // 3. Apply full-text search
      if (searchText.value.isNotEmpty) {
        final query = searchText.value.toLowerCase();
        filteredRows = filteredRows.where((row) {
          return toSearchString(row).toLowerCase().contains(query);
        }).toList();
      }

      // 4. Apply multi-column sort chain (sorted by priority ascending)
      final sortChain = activeSortConfigs.value
          .where((c) => c.enabled)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));

      if (sortChain.isNotEmpty) {
        filteredRows.sort((a, b) {
          for (final col in sortChain) {
            final fieldA = a.cells[col.field]?.value;
            final fieldB = b.cells[col.field]?.value;
            int cmp;
            if (fieldA is Comparable && fieldB is Comparable) {
              cmp = fieldA.compareTo(fieldB);
            } else {
              cmp = fieldA?.toString().compareTo(fieldB?.toString() ?? '') ?? 0;
            }
            if (cmp != 0) return col.ascending ? cmp : -cmp;
          }
          return 0;
        });
      }

      // 5. Replace grid rows atomically
      final currentRows = sm.rows;
      if (currentRows.isNotEmpty) sm.removeRows(currentRows);
      if (filteredRows.isNotEmpty) sm.appendRows(filteredRows);
      sm.notifyListeners();

      return null;
    }, [rows, searchText.value, activeFilters.value, activeSortConfigs.value, stateManager.value]);

    /// Opens the dialog for the currently focused row/cell.
    /// Called from both the Enter key handler and the double-click handler.
    void activateCurrentCell() {
      final sm = stateManager.value;
      if (sm == null) return;
      final row = sm.currentRow;
      final cell = sm.currentCell;
      if (row == null || cell == null) return;
      sm.setEditing(false);
      onRowActivated(row, cell.column.field);
    }

    return Column(
      children: [
        // ── Toolbar ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              // Full-text search field
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Suche...',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: searchText.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              searchController.clear();
                              searchText.value = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => searchText.value = val,
                ),
              ),
              const Gap(8),

              // Column filter button with active-filter badge
              Badge(
                isLabelVisible: activeFilters.value.isNotEmpty,
                label: Text(activeFilters.value.length.toString()),
                child: IconButton.outlined(
                  tooltip: 'Spaltenfilter',
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final result = await FilterSettingsDialog.show(
                      context,
                      allRows: rows,
                      columns: columns,
                      initialFilters: activeFilters.value,
                    );
                    if (result != null) activeFilters.value = result;
                  },
                ),
              ),
              const Gap(8),

              // Multi-sort button with enabled-column badge
              Badge(
                isLabelVisible: activeSortConfigs.value.any((c) => c.enabled),
                label: Text(
                  activeSortConfigs.value.where((c) => c.enabled).length.toString(),
                ),
                child: IconButton.outlined(
                  tooltip: 'Sortierung konfigurieren',
                  icon: const Icon(Icons.filter_list),
                  onPressed: () async {
                    final result = await SortSettingsDialog.show(
                      context,
                      initialConfigs: activeSortConfigs.value,
                    );
                    if (result != null) activeSortConfigs.value = result;
                  },
                ),
              ),

              // Optional "Neu" button — rendered only when onCreateNew is set
              if (onCreateNew != null) ...[
                const Gap(8),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Neu'),
                  onPressed: onCreateNew,
                ),
              ],
            ],
          ),
        ),

        // ── PlutoGrid with Enter-key interception ──────────────────────────
        Expanded(
          child: Focus(
            // onKeyEvent bubbles up from PlutoGrid's internal focus tree.
            // Since editing is disabled, PlutoGrid does not consume Enter —
            // we handle it here to activate the dialog for the current row.
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                activateCurrentCell();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: PlutoGrid(
              columns: columns,
              rows: List.from(rows),
              onLoaded: (PlutoGridOnLoadedEvent event) {
                stateManager.value = event.stateManager;
                // Disable the built-in PlutoGrid column-filter row — we use
                // our own FilterSettingsDialog instead.
                event.stateManager.setShowColumnFilter(false);
              },
              onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) {
                stateManager.value?.setEditing(false);
                onRowActivated(event.row, event.cell.column.field);
              },
              onSelected: (PlutoGridOnSelectedEvent event) {
                if (event.row != null && onRowSelected != null) {
                  onRowSelected!(event.row!);
                }
              },
              configuration: PlutoGridConfiguration(
                style: const PlutoGridStyleConfig(
                  enableColumnBorderVertical: true,
                  enableColumnBorderHorizontal: true,
                  oddRowColor: Color(0xFFF9F9F9),
                ),
                columnFilter: PlutoGridColumnFilterConfig(
                  filters: const [...FilterHelper.defaultFilters],
                ),
                localeText: appGermanLocaleText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
