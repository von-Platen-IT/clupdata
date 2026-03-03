import 'package:flutter/material.dart';

/// A reusable standard dropdown field optimized for desktop usage and keyboard traversal.
class AppDropdownField<T> extends StatelessWidget {
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
    // Determine the initially selected value based on the controller's current text
    final initialSelection = options.where((o) => getLabel(o) == controller.text).firstOrNull;

    return DropdownButtonFormField<T>(
      value: initialSelection,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      items: options.map((option) {
        return DropdownMenuItem<T>(
          value: option,
          child: Text(getLabel(option)),
        );
      }).toList(),
      onChanged: (T? newValue) {
        if (newValue != null) {
          controller.text = getLabel(newValue);
        }
      },
    );
  }
}
