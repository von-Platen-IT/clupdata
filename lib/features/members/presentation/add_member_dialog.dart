import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'members_controller.dart';

/// A modular dialog window for creating a new member.
///
/// This component utilizes `flutter_hooks` to manage its internal form state
/// (e.g. text controllers, loading spinners) without needing a `StatefulWidget`.
/// Upon submission, it triggers the [MembersActions.addMember] action.
class AddMemberDialog extends HookConsumerWidget {
  /// Creates the dialog.
  const AddMemberDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstNameController = useTextEditingController();
    final lastNameController = useTextEditingController();
    final isSaving = useState(false);

    return AlertDialog(
      title: const Text('Neues Mitglied'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(
                labelText: 'Vorname',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const Gap(16),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(
                labelText: 'Nachname',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(context, ref, firstNameController.text, lastNameController.text, isSaving),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: isSaving.value
              ? null
              : () => _save(context, ref, firstNameController.text, lastNameController.text, isSaving),
          child: isSaving.value 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Speichern'),
        ),
      ],
    );
  }

  Future<void> _save(
    BuildContext context, 
    WidgetRef ref, 
    String firstName, 
    String lastName,
    ValueNotifier<bool> isSaving,
  ) async {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) return;
    
    isSaving.value = true;
    try {
      await ref.read(membersActionsProvider.notifier).addMember(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
      );
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      isSaving.value = false;
    }
  }
}
