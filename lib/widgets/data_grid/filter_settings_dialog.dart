import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pluto_grid/pluto_grid.dart';

class FilterSettingsDialog extends HookWidget {
  final List<PlutoColumn> columns;
  final List<PlutoRow> allRows; // Raw unfiltered rows to extract unique values
  final Map<String, String> activeFilters;

  const FilterSettingsDialog({
    super.key,
    required this.columns,
    required this.allRows,
    required this.activeFilters,
  });

  @override
  Widget build(BuildContext context) {
    // Only show columns that are allowed to be filtered
    final filterableColumns = columns.where((c) => c.enableFilterMenuItem).toList();
    
    // State to hold current edits
    final filtersState = useState<Map<String, String>>(Map.from(activeFilters));
    final resetTrigger = useState(0);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Filter'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: filterableColumns.map((col) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      col.title,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Gap(8),
                    _FilterAutocomplete(
                      // We use resetTrigger as a key part to force rebuild on reset
                      key: ValueKey('${col.field}_${resetTrigger.value}'),
                      initialValue: filtersState.value[col.field] ?? '',
                      options: _getDistinctValuesForColumn(col.field),
                      onChanged: (val) {
                        final newFilters = Map<String, String>.from(filtersState.value);
                        if (val.trim().isEmpty) {
                          newFilters.remove(col.field);
                        } else {
                          newFilters[col.field] = val;
                        }
                        filtersState.value = newFilters;
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            filtersState.value = {};
            resetTrigger.value++;
          },
          child: const Text('Filter zurücksetzen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(filtersState.value),
          child: const Text('Anwenden'),
        ),
      ],
    );
  }

  List<String> _getDistinctValuesForColumn(String field) {
    final values = allRows
        .map((row) => row.cells[field]?.value?.toString() ?? '')
        .where((val) => val.trim().isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }
}

class _FilterAutocomplete extends HookWidget {
  final String initialValue;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterAutocomplete({
    super.key,
    required this.initialValue,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final focusNode = useFocusNode();
    final controller = useTextEditingController(text: initialValue);

    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<String>(
        initialValue: TextEditingValue(text: initialValue),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return options;
          }
          final query = textEditingValue.text.toLowerCase();
          return options.where((option) => option.toLowerCase().contains(query));
        },
        onSelected: (String selection) {
          onChanged(selection);
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          // Sync changes from free typing, not just selection
          controller.text = textEditingController.text;
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              hintText: 'Alle',
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onFieldSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 200,
                  maxWidth: constraints.maxWidth,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(option),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
