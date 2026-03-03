import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import 'widgets/waren_data_grid.dart';
import 'widgets/waren_edit_dialog.dart';

class WarenScreen extends HookConsumerWidget {
  const WarenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waren'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => WarenEditDialog.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Neue Ware'),
          ),
          const Gap(16),
        ],
      ),
      body: const WarenDataGrid(),
    );
  }
}
