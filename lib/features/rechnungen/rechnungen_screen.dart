import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../common_widgets/app_dialog_delete_action.dart';
import '../../common_widgets/bemerkung_detail_view.dart';
import '../../common_widgets/feature_screen_scaffold.dart';
import '../../core/data/bemerkung_repository.dart';
import '../../core/database/database.dart';
import 'data/rechnungen_repository.dart';
import 'widgets/neue_rechnung_dialog.dart';
import 'widgets/rechnung_data_grid.dart';

/// Main screen for the Rechnungen (invoices) module.
class RechnungenScreen extends HookConsumerWidget {
  const RechnungenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRowId = useState<int?>(null);

    // Stream bemerkung for the selected row
    final bemerkungStream = useMemoized(
      () => selectedRowId.value != null
          ? ref
                .read(rechnungenRepositoryProvider)
                .watchBemerkungForRechnung(selectedRowId.value!)
          : const Stream<BemerkungData?>.empty(),
      [selectedRowId.value],
    );
    final bemerkungAsync = useStream(bemerkungStream);

    return FeatureScreenScaffold(
      title: 'Rechnungen',
      hasSelection: selectedRowId.value != null,
      onCreateNew: () => NeueRechnungDialog.show(context),
      onDeleteSelection: () async {
        if (selectedRowId.value == null) return;
        final confirm = await AppDialogDeleteAction.showDeleteConfirmation(
          context,
          entityName: 'die ausgewählte Rechnung',
        );
        if (confirm && context.mounted) {
          try {
            await ref
                .read(rechnungenRepositoryProvider)
                .deleteRechnung(selectedRowId.value!);
            selectedRowId.value = null;
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fehler beim Löschen: $e')),
              );
            }
          }
        }
      },
      bottomPanel: selectedRowId.value != null
          ? BemerkungDetailView(
              bemerkung: bemerkungAsync.data,
              entityName: 'Rechnung',
              onSave: (titel, text) => ref
                  .read(bemerkungRepositoryProvider)
                  .saveBemerkung(bemerkungAsync.data?.id, titel, text),
            )
          : null,
      body: RechnungDataGrid(
        onRowSelected: (row) {
          selectedRowId.value = row?.rechnung.id;
        },
      ),
    );
  }
}
