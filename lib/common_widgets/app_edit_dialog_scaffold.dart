import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'app_dialog_delete_action.dart';

/// Returns `true` when the currently focused widget should consume the
/// [LogicalKeyboardKey.enter] key itself (multi-line text fields, dropdown
/// menu entries). Suppresses the global "save on Enter" shortcut in those cases.
bool _shouldSuppressEnter() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return false;
  final context = primaryFocus.context;
  if (context == null) return false;
  
  // Find the nearest EditableText ancestor
  final editableText = context.findAncestorWidgetOfExactType<EditableText>();
  if (editableText != null && editableText.maxLines != 1) return true;
  
  // DropdownMenu uses _DropdownMenuBody
  final dropdownMenu = context.findAncestorWidgetOfExactType<DropdownMenu>();
  if (dropdownMenu != null) return true;
  
  return false;
}

/// Standardized scaffold for entity edit/create dialogs.
/// Handles keyboard shortcuts (ESC to close, ENTER to save),
/// the layout structure, and the standard action buttons (Save, Cancel, Delete).
class AppEditDialogScaffold extends StatelessWidget {
  final String title;
  final Widget content;
  final bool isSaving;
  final VoidCallback onSave;
  final double contentWidth;

  /// If provided, a delete button is shown on the left side of the actions row.
  final Future<void> Function()? onDelete;
  /// The label for the entity to be deleted (e.g. 'Mitglied', 'Ware').
  final String? deleteEntityLabel;

  const AppEditDialogScaffold({
    super.key,
    required this.title,
    required this.content,
    required this.isSaving,
    required this.onSave,
    this.contentWidth = 800,
    this.onDelete,
    this.deleteEntityLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (context.mounted) Navigator.of(context).pop();
        },
        // Enter triggers save only when no multi-line or dropdown has focus
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!isSaving && !_shouldSuppressEnter()) onSave();
        },
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Schließen',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: contentWidth,
            child: SingleChildScrollView(
              child: content,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            // Delete button — only shown when a delete callback is provided
            if (onDelete != null && deleteEntityLabel != null)
              AppDialogDeleteAction(
                entityLabel: deleteEntityLabel!,
                onConfirmed: onDelete!,
              )
            else
              const SizedBox.shrink(),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const Gap(8),
                FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
