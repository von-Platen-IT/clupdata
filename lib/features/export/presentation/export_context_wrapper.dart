import 'package:flutter/material.dart';

import '../../../core/providers/export_context_provider.dart';

/// A widget that sets the export context when a detail dialog is opened
/// and clears it when the dialog is closed.
///
/// Usage:
/// ```dart
/// ExportContextWrapper(
///   item: member,
///   entityType: 'mitglied',
///   title: 'Mitglied ${member.name}',
///   child: MemberEditDialogContent(...),
/// )
/// ```
class ExportContextWrapper extends StatefulWidget {
  /// The item being edited/viewed.
  final dynamic item;

  /// The entity type identifier.
  final String entityType;

  /// The display title.
  final String title;

  /// Optional subtitle.
  final String? subtitle;

  /// The child widget (the actual dialog content).
  final Widget child;

  const ExportContextWrapper({
    super.key,
    required this.item,
    required this.entityType,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  State<ExportContextWrapper> createState() => _ExportContextWrapperState();
}

class _ExportContextWrapperState extends State<ExportContextWrapper> {
  @override
  void initState() {
    super.initState();
    // Set export context when dialog opens
    exportContextNotifier.setDetailContext(
      widget.item,
      entityType: widget.entityType,
      title: widget.title,
      subtitle: widget.subtitle,
    );
  }

  @override
  void dispose() {
    // Clear export context when dialog closes
    exportContextNotifier.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Helper function to show a dialog with export context.
///
/// This is a convenience wrapper around showDialog that automatically
/// sets and clears the export context.
Future<T?> showDialogWithExportContext<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  required dynamic item,
  required String entityType,
  required String title,
  String? subtitle,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      return ExportContextWrapper(
        item: item,
        entityType: entityType,
        title: title,
        subtitle: subtitle,
        child: Builder(builder: builder),
      );
    },
  );
}
