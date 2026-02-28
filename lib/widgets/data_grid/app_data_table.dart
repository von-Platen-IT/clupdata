import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

import 'data_table_column.dart';

/// A generic, reusable, object-oriented data table component for desktop.
/// Handles sorting, an optional search bar, single row selection, and double-tap actions.
class AppDataTable<T> extends HookWidget {
  /// The raw list of items to display.
  final List<T> items;

  /// Column definitions.
  final List<DataTableColumn<T>> columns;

  /// Callback when a row is tapped once.
  final void Function(T item)? onRowSelected;

  /// Callback when a row is double tapped.
  final void Function(T item)? onRowDoubleTap;

  /// Optional global search logic. If provided, a search bar appears.
  /// The function should return true if the item matches the query.
  final bool Function(T item, String query)? searchFilter;

  /// Currently selected item, if managed externally.
  final T? selectedItem;

  const AppDataTable({
    super.key,
    required this.items,
    required this.columns,
    this.onRowSelected,
    this.onRowDoubleTap,
    this.searchFilter,
    this.selectedItem,
  });

  @override
  Widget build(BuildContext context) {
    final sortColumnIndex = useState<int?>(null);
    final isAscending = useState<bool>(true);
    final searchQuery = useState<String>('');
    final localSelectedItem = useState<T?>(selectedItem);

    // Sync external selected item if it changes
    useEffect(() {
      localSelectedItem.value = selectedItem;
      return null;
    }, [selectedItem]);

    // Apply filtering and sorting
    final processedItems = useMemoized(() {
      List<T> result = List.from(items);

      // Search
      if (searchFilter != null && searchQuery.value.trim().isNotEmpty) {
        final query = searchQuery.value.trim().toLowerCase();
        result = result.where((item) => searchFilter!(item, query)).toList();
      }

      // Sort
      if (sortColumnIndex.value != null) {
        final col = columns[sortColumnIndex.value!];
        if (col.sortable) {
          result.sort((a, b) {
            final valA = col.sortExtractor?.call(a) ?? col.valueExtractor?.call(a);
            final valB = col.sortExtractor?.call(b) ?? col.valueExtractor?.call(b);

            int cmp = 0;
            if (valA == null && valB == null) cmp = 0;
            else if (valA == null) cmp = -1;
            else if (valB == null) cmp = 1;
            else {
              cmp = Comparable.compare(valA, valB);
            }

            return isAscending.value ? cmp : -cmp;
          });
        }
      }

      return result;
    }, [items, sortColumnIndex.value, isAscending.value, searchQuery.value]);

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar (Search)
        if (searchFilter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Suche...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => searchQuery.value = '',
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => searchQuery.value = val,
                  ),
                ),
              ],
            ),
          ),

        // Header Row
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: List.generate(columns.length, (index) {
              final col = columns[index];
              return _buildHeaderCell(
                col: col,
                isSorted: sortColumnIndex.value == index,
                isAscending: isAscending.value,
                onSort: () {
                  if (col.sortable) {
                    if (sortColumnIndex.value == index) {
                      // Toggle sort mode or remove sort if tapped 3rd time
                      if (isAscending.value) {
                        isAscending.value = false;
                      } else {
                        sortColumnIndex.value = null; // reset
                      }
                    } else {
                      sortColumnIndex.value = index;
                      isAscending.value = true;
                    }
                  }
                },
              );
            }),
          ),
        ),
        
        const Divider(height: 1),

        // Data Rows
        Expanded(
          child: processedItems.isEmpty
              ? const Center(child: Text('Keine Daten gefunden.'))
              : ListView.builder(
                  itemCount: processedItems.length,
                  itemBuilder: (context, index) {
                    final item = processedItems[index];
                    final isSelected = localSelectedItem.value == item;

                    return _DataRow<T>(
                      item: item,
                      columns: columns,
                      isSelected: isSelected,
                      onTap: () {
                        localSelectedItem.value = item;
                        if (onRowSelected != null) {
                          onRowSelected!(item);
                        }
                      },
                      onDoubleTap: () {
                        if (onRowDoubleTap != null) {
                          onRowDoubleTap!(item);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell({
    required DataTableColumn<T> col,
    required bool isSorted,
    required bool isAscending,
    required VoidCallback onSort,
  }) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: col.alignment == Alignment.center
          ? MainAxisAlignment.center
          : (col.alignment == Alignment.centerRight ? MainAxisAlignment.end : MainAxisAlignment.start),
      children: [
        Text(
          col.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        if (col.sortable && isSorted) ...[
          const Gap(4),
          Icon(
            isAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
          ),
        ]
      ],
    );

    if (col.sortable) {
      content = GestureDetector(
        onTap: onSort,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    if (col.fixedWidth != null) {
      return SizedBox(
        width: col.fixedWidth,
        child: Align(alignment: col.alignment, child: content),
      );
    } else {
      return Expanded(
        flex: col.flex,
        child: Align(alignment: col.alignment, child: content),
      );
    }
  }
}

class _DataRow<T> extends StatelessWidget {
  final T item;
  final List<DataTableColumn<T>> columns;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _DataRow({
    required this.item,
    required this.columns,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected 
            ? theme.colorScheme.primaryContainer.withAlpha(150)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: columns.map((col) {
            Widget cellContent;
            if (col.cellBuilder != null) {
              cellContent = col.cellBuilder!(item);
            } else {
              cellContent = Text(
                col.valueExtractor!(item),
                overflow: TextOverflow.ellipsis,
              );
            }

            if (col.fixedWidth != null) {
              return SizedBox(
                width: col.fixedWidth,
                child: Align(alignment: col.alignment, child: cellContent),
              );
            } else {
              return Expanded(
                flex: col.flex,
                child: Align(alignment: col.alignment, child: cellContent),
              );
            }
          }).toList(),
        ),
      ),
    );
  }
}
