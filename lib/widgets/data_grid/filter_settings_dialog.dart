import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:gap/gap.dart';

/// Modal dialog for configuring column-level filters.
/// Provides an [Autocomplete] field per filterable column, with options
/// derived from the distinct values already present in [allRows].
class FilterSettingsDialog extends HookWidget {
  /// All rows from the unfiltered dataset — used to derive autocomplete options.
  final List<PlutoRow> allRows;

  /// All visible columns; only those with [PlutoColumn.enableFilterMenuItem]
  /// set to `true` will appear as filter fields.
  final List<PlutoColumn> columns;

  /// The currently active filter values, keyed by column field name.
  final Map<String, String> initialFilters;

  const FilterSettingsDialog({
    super.key,
    required this.allRows,
    required this.columns,
    required this.initialFilters,
  });

  /// Opens the filter dialog and returns the updated filter map,
  /// or `null` if cancelled. An empty map signals "reset all filters".
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required List<PlutoRow> allRows,
    required List<PlutoColumn> columns,
    required Map<String, String> initialFilters,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => FilterSettingsDialog(
        allRows: allRows,
        columns: columns,
        initialFilters: initialFilters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only columns explicitly marked as filterable appear in the dialog
    final filterableColumns = useMemoized(
      () => columns.where((c) => c.enableFilterMenuItem).toList(),
      [columns],
    );

    // Pre-compute distinct values per column field once — safe to do at
    // widget build level (not inside itemBuilder, where hooks are forbidden)
    final optionsByField = useMemoized<Map<String, List<String>>>(() {
      return {
        for (final col in filterableColumns)
          col.field:
              allRows
                  .map((r) => r.cells[col.field]?.value?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort(),
      };
    }, [filterableColumns, allRows]);

    // Local mutable copy of filters — changes are only committed on "Anwenden"
    final filterState = useState<Map<String, String>>(
      Map.fromEntries(initialFilters.entries.where((e) => e.value.isNotEmpty)),
    );

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Filter'),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Schließen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: filterableColumns.isEmpty
            ? const Text('Keine filterbaren Spalten konfiguriert.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: filterableColumns.length,
                separatorBuilder: (_, _) => const Gap(16),
                itemBuilder: (context, index) {
                  final col = filterableColumns[index];
                  final options = optionsByField[col.field] ?? [];

                  return _FilterColumnField(
                    column: col,
                    options: options,
                    initialValue: filterState.value[col.field] ?? '',
                    onChanged: (value) {
                      filterState.value = {
                        ...filterState.value,
                        col.field: value,
                      };
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          // Pop with an empty map to signal "reset all"
          onPressed: () => Navigator.of(context).pop(<String, String>{}),
          child: const Text('Filter zurücksetzen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(filterState.value),
          child: const Text('Anwenden'),
        ),
      ],
    );
  }
}

/// A single filter field for one column, using [Autocomplete] with options
/// derived from the existing distinct values in that column.
///
/// Extracted as a [StatefulWidget] so that the [TextEditingController] can be
/// properly disposed and its listener cleaned up — fixing the Memory Leak
/// that occurred when [addListener] was called inside [fieldViewBuilder].
class _FilterColumnField extends StatefulWidget {
  final PlutoColumn column;
  final List<String> options;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _FilterColumnField({
    required this.column,
    required this.options,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_FilterColumnField> createState() => _FilterColumnFieldState();
}

class _FilterColumnFieldState extends State<_FilterColumnField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.column.title,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Gap(4),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: widget.initialValue),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return widget.options;
            return widget.options.where((option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },
          onSelected: (String selection) {
            _controller.text = selection;
            widget.onChanged(selection);
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                // Sync the Autocomplete's internal controller with our managed controller
                // by replacing its text on selection — we do NOT attach our listener here.
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: 'Nach ${widget.column.title} filtern...',
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  onChanged: (value) => widget.onChanged(value),
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
        ),
      ],
    );
  }
}
