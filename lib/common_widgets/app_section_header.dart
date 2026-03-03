import 'package:flutter/material.dart';

/// A standardized section header widget used inside modal edit dialogs
/// to visually separate different groups of form fields.
class AppSectionHeader extends StatelessWidget {
  /// The section title displayed as bold, medium-weight text.
  final String title;

  const AppSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
