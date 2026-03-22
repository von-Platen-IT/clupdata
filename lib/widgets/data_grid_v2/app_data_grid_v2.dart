import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:gap/gap.dart';

import 'data_grid_column_config.dart';
import 'data_grid_controller.dart';
import 'data_grid_locale_de.dart';
import 'filter_settings_dialog.dart';
import 'sort_settings_dialog.dart';

/// A generic, fully reusable data grid widget built on top of [PlutoGrid].
///
/// Encapsulates full-text search, multi-column sort, column filtering,
/// row selection, double-click detail modal support, row background coloring,
/// and a headless [DataGridController] API for programmatic access.
///
/// The widget is completely domain-agnostic. All domain-specific behavior
/// (columns, data mapping, dialogs) is configured via constructor parameters
/// and the generic type [T].
///
/// Example usage:
/// ```dart
/// AppDataGridV2<MyItem>(
///   items: myItems,
///   columnConfigs: myColumnConfigs,
///   toSearchString: (item) => '${item.name} ${item.category}',
///   toJson: (item) => item.toJson(),
///   fromJson: MyItem.fromJson,
///   detailModalBuilder: (item, colId) => MyEditDialog.show(context, item),
/// )
/// ```
class AppDataGridV2<T> extends HookWidget {
  /// The raw data items to display in the grid.
  final List<T> items;

  /// Column configurations that define layout, behavior, and data extraction.
  final List<DataGridColumnConfig<T>> columnConfigs;

  /// Builds the full-text search string for a given item.
  /// Should return all searchable field values joined by spaces.
  final String Function(T item) toSearchString;

  /// Serializes an item to a JSON-compatible Map (for export/CRUD API).
  final Map<String, dynamic> Function(T item) toJson;

  /// Deserializes an item from a JSON-compatible Map (for import/CRUD API).
  final T Function(Map<String, dynamic> json) fromJson;

  /// Called when a new item should be persisted (Section 2.3).
  final void Function(T item)? onItemCreated;

  /// Called when an existing item should be updated (Section 2.3).
  final void Function(T item)? onItemUpdated;

  /// Called when an item should be deleted (Section 2.3).
  final void Function(T item)? onItemDeleted;

  /// Called when a row is activated (double-click or Enter key).
  /// [item] is the domain object, [focusedColumnId] is the clicked column
  /// field name — used to set initial focus in the modal dialog.
  final void Function(T item, String focusedColumnId)? detailModalBuilder;

  /// Called when a list export is requested via the toolbar export button.
  final void Function(String json)? onListExportRequested;

  /// Called when a detail export for a single item is requested.
  final void Function(String json)? onDetailExportRequested;

  /// Resolves row background color based on the data item.
  /// Return `null` for the default row color.
  final Color? Function(T item)? rowBgColorResolver;

  /// Called when the selected row changes via single-click.
  final void Function(T? item)? onRowSelected;

  /// Optional external controller for headless/programmatic access.
  /// If not provided, an internal controller is created and managed.
  final DataGridController<T>? controller;

  const AppDataGridV2({
    super.key,
    required this.items,
    required this.columnConfigs,
    required this.toSearchString,
    required this.toJson,
    required this.fromJson,
    this.onItemCreated,
    this.onItemUpdated,
    this.onItemDeleted,
    this.detailModalBuilder,
    this.onListExportRequested,
    this.onDetailExportRequested,
    this.rowBgColorResolver,
    this.onRowSelected,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // ── Controller Setup ──────────────────────────────────────────────────
    final ownsController = controller == null;
    final ctrl = useMemoized(
      () =>
          controller ??
          DataGridController<T>(
            columnConfigs: columnConfigs,
            toJson: toJson,
            fromJson: fromJson,
            toSearchString: toSearchString,
            onItemCreated: onItemCreated,
            onItemUpdated: onItemUpdated,
            onItemDeleted: onItemDeleted,
          ),
      [controller],
    );

    // Dispose internal controller on unmount
    useEffect(() {
      if (ownsController) return ctrl.dispose;
      return null;
    }, [ctrl]);

    // Sync CRUD callbacks when they change
    useEffect(() {
      ctrl.onItemCreated = onItemCreated;
      ctrl.onItemUpdated = onItemUpdated;
      ctrl.onItemDeleted = onItemDeleted;
      return null;
    }, [onItemCreated, onItemUpdated, onItemDeleted]);

    // Push items into controller when source data changes
    useEffect(() {
      ctrl.updateItems(items);
      return null;
    }, [items]);

    // Rebuild widget when controller state changes
    useListenable(ctrl);

    // ── PlutoGrid State Manager ───────────────────────────────────────────
    final stateManager = useState<PlutoGridStateManager?>(null);

    // ── Search UI State ───────────────────────────────────────────────────
    final searchController = useTextEditingController();
    final hasSearchText = useState(false);
    final debounceTimer = useRef<Timer?>(null);
    useEffect(() => () => debounceTimer.value?.cancel(), []);

    // ── Create PlutoColumns from configs ───────────────────────────────────
    final plutoColumns = useMemoized(
      () => columnConfigs.map((c) => c.toPlutoColumn()).toList(),
      [columnConfigs],
    );

    // ── Map ALL items to PlutoRows (for filter dialog autocomplete) ───────
    final allPlutoRows = useMemoized(() {
      return items.map((item) {
        final cells = <String, PlutoCell>{};
        for (final config in columnConfigs) {
          cells[config.field] = PlutoCell(value: config.valueExtractor(item));
        }
        return PlutoRow(cells: cells);
      }).toList();
    }, [items, columnConfigs]);

    // ── Map filtered/sorted items to PlutoRows (for display) ──────────────
    final filteredItems = ctrl.filteredSortedItems;
    final rowItemMap = useRef<Map<Key, T>>({});

    final plutoRows = useMemoized(() {
      final rows = <PlutoRow>[];
      final map = <Key, T>{};

      for (final item in filteredItems) {
        final cells = <String, PlutoCell>{};
        for (final config in columnConfigs) {
          cells[config.field] = PlutoCell(value: config.valueExtractor(item));
        }
        final row = PlutoRow(cells: cells);
        rows.add(row);
        map[row.key] = item;
      }

      rowItemMap.value = map;
      return rows;
    }, [filteredItems, columnConfigs]);

    // ── Sync PlutoRows to PlutoGrid StateManager ──────────────────────────
    // We explicitly bypass PlutoGrid's internal `widget.rows` diffing by passing
    // an empty list below, and exclusively manage the rows here. This guarantees
    // that the `PlutoRow` instances in the grid are *exactly* the ones we mapped,
    // preserving their keys for double-click lookups and preserving selection
    // across parent rebuilds that do not change `plutoRows`.
    useEffect(() {
      final sm = stateManager.value;
      if (sm == null) return null;

      sm.removeAllRows();
      if (plutoRows.isNotEmpty) {
        sm.appendRows(plutoRows);
      }
      
      return null;
    }, [plutoRows, stateManager.value]);

    // ── Track row selection via PlutoGrid StateManager listener ────────────
    useEffect(() {
      final sm = stateManager.value;
      if (sm == null || onRowSelected == null) return null;

      PlutoRow? lastSelectedRow = sm.currentRow;

      void listener() {
        final currentRow = sm.currentRow;
        if (currentRow != lastSelectedRow) {
          lastSelectedRow = currentRow;
          final item =
              currentRow != null ? rowItemMap.value[currentRow.key] : null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) onRowSelected!(item);
          });
        }
      }

      sm.addListener(listener);
      return () => sm.removeListener(listener);
    }, [stateManager.value, onRowSelected]);

    // ── Row activation (double-click or Enter) ────────────────────────────
    void activateRow(PlutoRow row, String fieldName) {
      stateManager.value?.setEditing(false);
      final item = rowItemMap.value[row.key];
      if (item != null) {
        detailModalBuilder?.call(item, fieldName);
      }
    }

    // ── Row color resolver ────────────────────────────────────────────────
    PlutoRowColorCallback? rowColorCallback;
    if (rowBgColorResolver != null) {
      rowColorCallback = (PlutoRowColorContext ctx) {
        final item = rowItemMap.value[ctx.row.key];
        if (item != null) {
          return rowBgColorResolver!(item) ?? Colors.transparent;
        }
        return Colors.transparent;
      };
    }

    // ── Build ─────────────────────────────────────────────────────────────
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
                    suffixIcon: hasSearchText.value
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              searchController.clear();
                              hasSearchText.value = false;
                              debounceTimer.value?.cancel();
                              ctrl.searchText = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    hasSearchText.value = val.isNotEmpty;
                    debounceTimer.value?.cancel();
                    debounceTimer.value = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (context.mounted) ctrl.searchText = val;
                      },
                    );
                  },
                ),
              ),
              const Gap(8),

              // Column filter button with active-filter badge
              Badge(
                isLabelVisible: ctrl.activeFilters.isNotEmpty,
                label: Text(ctrl.activeFilters.length.toString()),
                child: IconButton.outlined(
                  tooltip: 'Spaltenfilter',
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final result = await FilterSettingsDialog.show(
                      context,
                      allRows: allPlutoRows,
                      columns: plutoColumns,
                      initialFilters: Map.from(ctrl.activeFilters),
                    );
                    if (result != null) ctrl.activeFilters = result;
                  },
                ),
              ),
              const Gap(8),

              // Multi-sort button with enabled-column badge
              Badge(
                isLabelVisible: ctrl.sortConfigs.any((c) => c.enabled),
                label: Text(
                  ctrl.sortConfigs.where((c) => c.enabled).length.toString(),
                ),
                child: IconButton.outlined(
                  tooltip: 'Sortierung konfigurieren',
                  icon: const Icon(Icons.filter_list),
                  onPressed: () async {
                    final result = await SortSettingsDialog.show(
                      context,
                      initialConfigs:
                          ctrl.sortConfigs.map((c) => c.copyWith()).toList(),
                    );
                    if (result != null) ctrl.sortConfigs = result;
                  },
                ),
              ),

              // Optional export button
              if (onListExportRequested != null) ...[
                const Gap(8),
                IconButton.outlined(
                  tooltip: 'Daten exportieren',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: () =>
                      onListExportRequested!(ctrl.getExportJson()),
                ),
              ],
            ],
          ),
        ),

        // ── PlutoGrid with Enter-key interception ──────────────────────────
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                final sm = stateManager.value;
                if (sm == null) return KeyEventResult.ignored;
                final row = sm.currentRow;
                final cell = sm.currentCell;
                if (row == null || cell == null) return KeyEventResult.ignored;
                activateRow(row, cell.column.field);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: PlutoGrid(
              columns: plutoColumns,
              rows: [], // Exclusively managed by useEffect above
              onLoaded: (PlutoGridOnLoadedEvent event) {
                stateManager.value = event.stateManager;
                event.stateManager.setShowColumnFilter(false);
              },
              onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) {
                activateRow(event.row, event.cell.column.field);
              },
              rowColorCallback: rowColorCallback,
              configuration: PlutoGridConfiguration(
                style: const PlutoGridStyleConfig(
                  enableColumnBorderVertical: true,
                  enableColumnBorderHorizontal: true,
                  oddRowColor: Color(0xFFF9F9F9),
                ),
                columnFilter: PlutoGridColumnFilterConfig(
                  filters: const [...FilterHelper.defaultFilters],
                ),
                localeText: dataGridGermanLocaleText,
                scrollbar: const PlutoGridScrollbarConfig(
                  isAlwaysShown: true,
                  scrollbarThickness: 12.0,
                  scrollbarThicknessWhileDragging: 16.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
