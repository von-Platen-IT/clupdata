import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:gap/gap.dart';

import 'app_data_grid_locale.dart';
import 'filter_settings_dialog.dart';
import 'sort_column_config.dart';
import 'sort_settings_dialog.dart';

/// The abstract base class for all tabular data screens in the application.
/// It provides common functionality like search, sort, filter, and the base
/// PlutoGrid setup. Child classes must inherit from this or wrap it, and provide
/// entity-specific configuration like columns, rows mapping, and search strings.
class AppDataGrid extends HookWidget {
  /// The list of items to display. Data objects are translated to PlutoRow inside the child class.
  final List<PlutoRow> rows;

  /// The columns defined according to structur.md rules.
  final List<PlutoColumn> columns;

  /// Defines which columns can be used in the multi-sort dialog.
  final List<SortColumnConfig> sortableColumns;

  /// Abstract hook invoked by the child class to determine if a specific row matches the search query.
  /// E.g. (row) => row.cells['name']?.value.toString()
  final String Function(PlutoRow row) toSearchString;

  /// Callback when a row is single-clicked (used to update external selection state if needed).
  /// Note: Inline editing is managed by PlutoGrid automatically if enableEditingMode is true.
  final void Function(PlutoRow row)? onRowSelected;

  /// Callback when a row is double-clicked (mandatory trigger for the feature-specific modal edit dialog).
  final void Function(PlutoGridOnRowDoubleTapEvent event) onRowDoubleTap;

  const AppDataGrid({
    super.key,
    required this.rows,
    required this.columns,
    required this.sortableColumns,
    required this.toSearchString,
    this.onRowSelected,
    required this.onRowDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    // State Manager for PlutoGrid
    final stateManager = useState<PlutoGridStateManager?>(null);

    // Search & Filter State
    final searchController = useTextEditingController();
    final searchText = useState<String>('');
    final activeFilters = useState<Map<String, String>>({});
    final activeSortConfigs = useState<List<SortColumnConfig>>(sortableColumns);

    // Effect: Apply all filters, search, and sort to the rows
    useEffect(() {
      final sm = stateManager.value;
      if (sm == null) return null;

      // 1. Start with all rows
      var filteredRows = List<PlutoRow>.from(rows);

      // 2. Apply explicit column filters
      if (activeFilters.value.isNotEmpty) {
        filteredRows = filteredRows.where((row) {
          for (final entry in activeFilters.value.entries) {
            final colField = entry.key;
            final filterValue = entry.value.toLowerCase();
            final cellValue = row.cells[colField]?.value?.toString().toLowerCase() ?? '';
            if (!cellValue.contains(filterValue)) return false;
          }
          return true;
        }).toList();
      }

      // 3. Apply full-text search
      if (searchText.value.isNotEmpty) {
        final query = searchText.value.toLowerCase();
        filteredRows = filteredRows.where((row) {
          final rowString = toSearchString(row).toLowerCase();
          return rowString.contains(query);
        }).toList();
      }

      // 4. Apply multi-column sort
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
            // Basic comparison, might need to be refined for specific types
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

      // Apply to grid (turn off pagination reset jumping)
      // Apply to grid
      final currentRows = sm.rows;
      if (currentRows.isNotEmpty) {
        sm.removeRows(currentRows);
      }
      if (filteredRows.isNotEmpty) {
        sm.appendRows(filteredRows);
      }
      
      // Force an update to PlutoGrid to ensure layout computes if this was the very first data load
      sm.notifyListeners();
      
      return null;
    }, [rows, searchText.value, activeFilters.value, activeSortConfigs.value, stateManager.value]); // Added stateManager.value to trigger when mounted

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
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
              const Gap(16),
              // Filter Button
              Badge(
                isLabelVisible: activeFilters.value.isNotEmpty,
                label: Text(activeFilters.value.length.toString()),
                child: IconButton.outlined(
                  tooltip: 'Spaltenfilter',
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final result = await FilterSettingsDialog.show(
                      context,
                      allRows: rows, // pass unfiltered rows to build autocomplete options
                      columns: columns,
                      initialFilters: activeFilters.value,
                    );
                    if (result != null) {
                      activeFilters.value = result;
                    }
                  },
                ),
              ),
              const Gap(8),
              // Sort Button
              Badge(
                isLabelVisible: activeSortConfigs.value.any((c) => c.enabled),
                label: Text(activeSortConfigs.value.where((c) => c.enabled).length.toString()),
                child: IconButton.outlined(
                  tooltip: 'Sortierung konfigurieren',
                  icon: const Icon(Icons.filter_list),
                  onPressed: () async {
                    final result = await SortSettingsDialog.show(
                      context,
                      initialConfigs: activeSortConfigs.value,
                    );
                    if (result != null) {
                      activeSortConfigs.value = result;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Grid
        Expanded(
          child: PlutoGrid(
            columns: columns,
            rows: List.from(rows), // Initialize with current rows, effect will manage updates
            onLoaded: (PlutoGridOnLoadedEvent event) {
              stateManager.value = event.stateManager;
              // Set readOnly for system columns inherently if needed, but PlutoColumn config should handle it.
              event.stateManager.setShowColumnFilter(false); // we use our own filter dialog
            },
            onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) {
               // Must end inline edit before opening modal!
               stateManager.value?.setKeepFocus(false);
               
               // Trigger child class logic (which should open modal and pass event.cell.column.field for focus)
               onRowDoubleTap(event);
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
              // German locale text per datagrid.md rule 10
              localeText: appGermanLocaleText,
            ),
          ),
        ),
      ],
    );
  }
}
