import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:gap/gap.dart';

class FilterSettingsDialog extends HookWidget {
  final List<PlutoRow> allRows;
  final List<PlutoColumn> columns;
  final Map<String, String> initialFilters;

  const FilterSettingsDialog({
    super.key,
    required this.allRows,
    required this.columns,
    required this.initialFilters,
  });

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
    // Only keep columns that have filtering explicitly enabled
    final filterableColumns = useMemoized(() {
      return columns.where((c) => c.enableFilterMenuItem).toList();
    }, [columns]);

    // Local state to keep track of changes before applying
    final filterState = useState<Map<String, String>>(
      Map.fromEntries(initialFilters.entries.where((e) => e.value.isNotEmpty)),
    );

    // Helper functions to get unique values for autocomplete
    List<String> getUniqueValuesForColumn(String field) {
      final values = allRows
          .map((r) => r.cells[field]?.value?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return values;
    }

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Filter'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Schließen',
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
                separatorBuilder: (context, index) => const Gap(16),
                itemBuilder: (context, index) {
                  final col = filterableColumns[index];
                  final options = useMemoized(
                      () => getUniqueValuesForColumn(col.field),
                      [col.field, allRows]);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        col.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Gap(4),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(
                          text: filterState.value[col.field] ?? '',
                        ),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return options;
                          }
                          return options.where((String option) {
                            return option
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                           filterState.value = {
                             ...filterState.value,
                             col.field: selection,
                           };
                        },
                        fieldViewBuilder: (context, textEditingController,
                            focusNode, onFieldSubmitted) {
                          // keep controller in sync with state if external clear happens
                          // We hook into the text controller to update the state on every keystroke
                          textEditingController.addListener(() {
                            final text = textEditingController.text;
                            final currentVal = filterState.value[col.field] ?? '';
                            if (text != currentVal) {
                               filterState.value = {
                                 ...filterState.value,
                                 col.field: text,
                               };
                            }
                          });

                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              isDense: true,
                              border: const OutlineInputBorder(),
                              hintText: 'Nach ${col.title} filtern...',
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                            ),
                            onSubmitted: (String value) {
                              onFieldSubmitted();
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Reset filters
            Navigator.of(context).pop(<String, String>{});
          },
          child: const Text('Filter zurücksetzen'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(filterState.value);
          },
          child: const Text('Anwenden'),
        ),
      ],
    );
  }
}
