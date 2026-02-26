import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'presentation/providers/members_list_provider.dart';
import 'widgets/member_data_grid.dart';

/// The main view for managing club members.
class MembersScreen extends HookConsumerWidget {
  /// Creates the members screen.
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(membersGridRowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitglieder'),
      ),
      body: Material(
        child: rowsAsync.when(
          data: (rows) => MemberDataGrid(rows: rows),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
        ),
      ),
    );
  }
}
