import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A reusable standard dropdown field optimized for desktop usage and keyboard traversal.
/// Uses DropdownMenu to support text input and autocomplete filtering.
class AppDropdownField<T> extends HookWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final List<T> options;
  final String Function(T) getLabel;
  final FocusNode? focusNode;

  const AppDropdownField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    required this.getLabel,
    this.required = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Manage FocusNode via hooks to ensure it's disposed and attached correctly
    final internalFocusNode = useFocusNode();
    final effectiveFocusNode = focusNode ?? internalFocusNode;

    // Determine the initially selected value based on the controller's current text
    final initialSelection = useMemoized(
      () => options.where((o) => getLabel(o) == controller.text).firstOrNull,
      [options, controller.text, getLabel]
    );

    // Validate text on focus loss
    useEffect(() {
      void listener() {
        if (!effectiveFocusNode.hasFocus) {
          final currentText = controller.text;
          final match = options.where((o) => getLabel(o) == currentText).firstOrNull;
          if (match == null && currentText.isNotEmpty) {
            controller.text = '';
          }
        }
      }
      effectiveFocusNode.addListener(listener);
      return () => effectiveFocusNode.removeListener(listener);
    }, [effectiveFocusNode, options, controller]);

    return DropdownMenu<T>(
      controller: controller,
      focusNode: effectiveFocusNode,
      initialSelection: initialSelection,
      label: Text(required ? '$label *' : label),
      enableFilter: true,
      requestFocusOnTap: true,
      // Disable the trailing icon from participating in keyboard focus traversal
      trailingIcon: const ExcludeFocus(child: Icon(Icons.arrow_drop_down)),
      selectedTrailingIcon: const ExcludeFocus(child: Icon(Icons.arrow_drop_up)),
      expandedInsets: EdgeInsets.zero, // Fills parent width like a normal input field
      dropdownMenuEntries: options.map((option) {
        return DropdownMenuEntry<T>(
          value: option,
          label: getLabel(option),
        );
      }).toList(),
      onSelected: (T? newValue) {
        if (newValue != null) {
          controller.text = getLabel(newValue);
          effectiveFocusNode.nextFocus();
        }
      },
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
