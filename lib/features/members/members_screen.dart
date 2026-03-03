import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'widgets/member_data_grid.dart';
import 'widgets/member_edit_dialog.dart';

/// The main view for managing club members.
class MembersScreen extends HookConsumerWidget {
  /// Creates the members screen.
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitglieder'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => MemberEditDialog.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Neu'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: const MemberDataGrid(),
    );
  }
}
