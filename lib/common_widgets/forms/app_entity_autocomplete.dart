import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A generic, reusable autocomplete widget for entity selection.
/// Eliminates code duplication between member and leistung selection.
///
/// Type parameter [T] represents the entity type (e.g., Mitglied, Leistung).
class AppEntityAutocomplete<T extends Object> extends HookWidget {
  final TextEditingController controller;
  final ValueNotifier<T?> selectedEntity;
  final String label;
  final String hintText;
  final String Function(T) displayStringForOption;
  final Widget Function(T) subtitleBuilder;
  final Future<List<T>> Function(String) onSearch;
  final Future<List<T>> Function() onLoadAll;
  final double optionsWidth;
  final double optionsMaxHeight;

  const AppEntityAutocomplete({
    super.key,
    required this.controller,
    required this.selectedEntity,
    required this.label,
    required this.hintText,
    required this.displayStringForOption,
    required this.subtitleBuilder,
    required this.onSearch,
    required this.onLoadAll,
    this.optionsWidth = 400,
    this.optionsMaxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    final searchResults = useState<List<T>>([]);

    Future<void> handleSearch(String query) async {
      if (query.length < 2) {
        searchResults.value = [];
        return;
      }
      final results = await onSearch(query);
      searchResults.value = results;
    }

    Future<void> handleLoadAll() async {
      final results = await onLoadAll();
      searchResults.value = results;
    }

    return Autocomplete<T>(
      optionsBuilder: (textEditingValue) {
        // Show all results when text is exactly ' ' (triggered by search button)
        if (textEditingValue.text == ' ') {
          return searchResults.value;
        }
        if (textEditingValue.text.length < 2) {
          return Iterable<T>.empty();
        }
        // Trigger search and return current results
        handleSearch(textEditingValue.text);
        return searchResults.value;
      },
      displayStringForOption: displayStringForOption,
      onSelected: (entity) {
        selectedEntity.value = entity;
        controller.text = displayStringForOption(entity);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // Sync external controller with internal one
            if (controller.text != textEditingController.text) {
              textEditingController.text = controller.text;
            }

            return Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hintText,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: selectedEntity.value != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              selectedEntity.value = null;
                              controller.clear();
                              textEditingController.clear();
                            },
                          )
                        : const SizedBox(width: 40, height: 40),
                  ),
                  onChanged: (value) {
                    controller.text = value;
                    if (selectedEntity.value != null) {
                      selectedEntity.value = null;
                    }
                  },
                ),
                if (selectedEntity.value == null)
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) async {
                        await handleLoadAll();
                      },
                      onTapUp: (_) {
                        textEditingController.text = ' ';
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
              ],
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: Container(
              width: optionsWidth,
              constraints: BoxConstraints(maxHeight: optionsMaxHeight),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final entity = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(displayStringForOption(entity)),
                    subtitle: subtitleBuilder(entity),
                    onTap: () => onSelected(entity),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
