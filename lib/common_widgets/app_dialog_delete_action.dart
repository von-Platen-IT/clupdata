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
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Wirklich löschen?'),
            content: Text(
              'Möchten Sie ${'diesen' /* grammatically generic */} $entityLabel unwiderruflich löschen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await onConfirmed();
        }
      },
    );
  }
}
