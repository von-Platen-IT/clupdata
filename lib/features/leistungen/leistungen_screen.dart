import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import 'widgets/leistung_data_grid.dart';
import 'widgets/leistung_edit_dialog.dart';

class LeistungenScreen extends HookConsumerWidget {
  const LeistungenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leistungen'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => LeistungEditDialog.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Neue Leistung'),
          ),
          const Gap(16),
        ],
      ),
      body: const LeistungDataGrid(),
    );
  }
}
