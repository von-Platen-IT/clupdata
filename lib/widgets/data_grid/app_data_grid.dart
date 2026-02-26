import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'app_data_grid_locale.dart';
import 'filter_settings_dialog.dart';
import 'sort_column_config.dart';
import 'sort_settings_dialog.dart';

abstract class AppDataGrid extends HookWidget {
  final List<PlutoColumn> columns;
  final List<PlutoRow> rows;
  final List<SortColumnConfig> sortableColumns;

  const AppDataGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.sortableColumns,
  });

  /// Abstract method to generate a searchable string from a row.
  String toSearchString(PlutoRow row);

  @override
  Widget build(BuildContext context) {
    final stateManager = useState<PlutoGridStateManager?>(null);
    final searchText = useState('');
    final activeFilters = useState<Map<String, String>>({});
    final sortPriority = useState<List<SortColumnConfig>>(
      List.from(sortableColumns),
    );

    // Apply filters, search and sort whenever they change
    void applyFiltersAndSort() {
      if (stateManager.value == null) return;
      
      final sm = stateManager.value!;
      sm.setShowLoading(true);

      // We start with all rows and filter them down
      List<PlutoRow> filteredRows = List.from(rows);

      // 1. Full-text Search
      final query = searchText.value.toLowerCase().trim();
      if (query.isNotEmpty) {
        filteredRows = filteredRows.where((row) {
          final searchStr = toSearchString(row).toLowerCase();
          return searchStr.contains(query);
        }).toList();
      }

      // 2. Column Filters (AND logic)
      if (activeFilters.value.isNotEmpty) {
        filteredRows = filteredRows.where((row) {
          bool match = true;
          for (final entry in activeFilters.value.entries) {
            final colField = entry.key;
            final filterVal = entry.value.toLowerCase();
            final cellVal = row.cells[colField]?.value?.toString().toLowerCase() ?? '';
            
            if (!cellVal.contains(filterVal)) {
              match = false;
              break;
            }
          }
          return match;
        }).toList();
      }

      // 3. Multi-Column Sort
      final sortChain = sortPriority.value
          .where((c) => c.enabled)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));

      if (sortChain.isNotEmpty) {
        filteredRows.sort((a, b) {
          for (final col in sortChain) {
            final valA = a.cells[col.field]?.value;
            final valB = b.cells[col.field]?.value;
            
            int cmp = 0;
            if (valA == null && valB == null) cmp = 0;
            else if (valA == null) cmp = -1;
            else if (valB == null) cmp = 1;
            else if (valA is Comparable && valB is Comparable) {
              cmp = valA.compareTo(valB);
            } else {
              cmp = valA.toString().compareTo(valB.toString());
            }

            if (cmp != 0) {
              return col.ascending ? cmp : -cmp;
            }
          }
          return 0;
        });
      }

      // Keep current Pluto grid state but replace rows
      // We do this by hiding all rows and showing only the filtered/sorted ones
      sm.refRows.clear();
      sm.refRows.addAll(filteredRows);
      
      // Update UI 
      sm.notifyListeners();
      sm.setShowLoading(false);
    }

    // Effect to re-apply whenever our state changes
    useEffect(() {
      applyFiltersAndSort();
      return null;
    }, [searchText.value, activeFilters.value, sortPriority.value, rows]);

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Suche...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchText.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => searchText.value = '',
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) => searchText.value = val,
                ),
              ),
              const Gap(8),
              Tooltip(
                message: 'Sortierung konfigurieren',
                child: Badge(
                  isLabelVisible: sortPriority.value.any((c) => c.enabled),
                  child: IconButton.outlined(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () async {
                      final newConfig = await showDialog<List<SortColumnConfig>>(
                        context: context,
                        builder: (ctx) => SortSettingsDialog(
                          initialConfig: sortPriority.value,
                        ),
                      );
                      if (newConfig != null) {
                        sortPriority.value = newConfig;
                      }
                    },
                  ),
                ),
              ),
              const Gap(8),
              Tooltip(
                message: 'Spaltenfilter',
                child: Badge(
                  isLabelVisible: activeFilters.value.isNotEmpty,
                  label: Text(activeFilters.value.length.toString()),
                  child: IconButton.outlined(
                    icon: const Icon(Icons.tune),
                    onPressed: () async {
                      final newFilters = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (ctx) => FilterSettingsDialog(
                          columns: columns,
                          allRows: rows,
                          activeFilters: activeFilters.value,
                        ),
                      );
                      if (newFilters != null) {
                        activeFilters.value = newFilters;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Grid
        Expanded(
          child: PlutoGrid(
            columns: columns,
            rows: List.from(rows), // Initial rows
            onLoaded: (PlutoGridOnLoadedEvent event) {
              stateManager.value = event.stateManager;
              applyFiltersAndSort();
            },
            onChanged: (PlutoGridOnChangedEvent event) {
              // Triggered when editing a cell, you might want to call an abstract method here
            },
            configuration: PlutoGridConfiguration(
              style: const PlutoGridStyleConfig(
                enableColumnBorderVertical: true,
                enableColumnBorderHorizontal: true,
                oddRowColor: Color(0xFFF9F9F9),
              ),
              columnFilter: PlutoGridColumnFilterConfig(
                filters: const [
                  ...FilterHelper.defaultFilters,
                ],
              ),
              localeText: appGermanLocaleText,
            ),
          ),
        ),
      ],
    );
  }
}
