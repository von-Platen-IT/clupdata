import 'package:flutter/material.dart';

import 'app_select_field.dart';

/// Thin wrapper around [AppSelectField] in [AppSelectMode.select] mode.
///
/// Kept for backwards compatibility — all existing call sites remain unchanged.
/// For [AppSelectMode.autocomplete], use [AppSelectField] directly.
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
    return AppSelectField<T>(
      controller: controller,
      label: label,
      options: options,
      getLabel: getLabel,
      mode: AppSelectMode.select,
      required: required,
      focusNode: focusNode,
    );
  }
}
