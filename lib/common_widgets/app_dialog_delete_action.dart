import 'package:flutter/material.dart';

/// A standardized delete button with a built-in confirmation dialog,
/// used in the [actions] area of modal edit dialogs.
///
/// Shows a red [TextButton.icon] that opens an [AlertDialog] asking the
/// user to confirm before calling [onConfirmed].
class AppDialogDeleteAction extends StatelessWidget {
  /// Human-readable name of the entity being deleted, shown in the
  /// confirmation dialog text. Example: `'Ware'`, `'Mitglied'`.
  final String entityLabel;

  /// Called only after the user explicitly confirms deletion in the
  /// secondary [AlertDialog]. Must perform the actual repository delete
  /// and close the parent dialog.
  final Future<void> Function() onConfirmed;

  const AppDialogDeleteAction({
    super.key,
    required this.entityLabel,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      label: const Text('Löschen', style: TextStyle(color: Colors.red)),
      onPressed: () async {
        final confirmed = await showDeleteConfirmation(
          context,
          entityName: entityLabel,
        );
        if (confirmed) {
          await onConfirmed();
        }
      },
    );
  }

  /// Shows a standardized delete confirmation dialog and returns `true`
  /// if the user confirmed, `false` otherwise.
  ///
  /// Use this in screen-level delete buttons instead of manually building
  /// the same [AlertDialog] each time.
  ///
  /// [entityName] is the human-readable name shown in the dialog text
  /// (e.g., 'Beitrag', 'Rechnung'). Defaults to 'Datensatz'.
  static Future<bool> showDeleteConfirmation(
    BuildContext context, {
    String entityName = 'Datensatz',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wirklich löschen?'),
        content: Text('Möchten Sie $entityName unwiderruflich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
