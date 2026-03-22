import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/feature_screen_scaffold.dart';
import '../../widgets/stammdaten_data_grid.dart';
import '../../widgets/stammdaten_edit_dialog.dart';

/// The main view for managing global configuration (Stammdaten).
class StammdatenScreen extends HookConsumerWidget {
  const StammdatenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // State to hold the currently selected row ID 
    // Stammdaten usually shouldn't be rigidly deleted (especially seed data),
    // but the FeatureScreenScaffold supports selection. We disable delete here 
    // by passing null to onDeleteSelection unless explicitly required.
    final selectedKey = useState<String?>(null);

    return FeatureScreenScaffold(
      title: 'Einstellungen (Stammdaten)',
      hasSelection: selectedKey.value != null,
      onCreateNew: () => StammdatenEditDialog.show(context),
      onDeleteSelection: null, // Deletion of system settings not allowed by default
      body: StammdatenDataGrid(
        onRowSelected: (row) {
          selectedKey.value = row?.schluessel;
        },
      ),
    );
  }
}
