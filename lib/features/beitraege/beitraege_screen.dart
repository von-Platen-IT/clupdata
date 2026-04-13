import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:clupdata/core/providers/create_action_provider.dart';
import '../../common_widgets/app_dialog_delete_action.dart';
import '../../common_widgets/bemerkung_detail_view.dart';
import '../../common_widgets/feature_screen_scaffold.dart';
import '../../core/data/bemerkung_repository.dart';
import '../../core/database/database.dart';
import 'data/beitraege_repository.dart';
import 'presentation/widgets/beitrag_data_grid.dart';
import 'presentation/dialogs/neuer_beitrag_dialog.dart';
import 'presentation/dialogs/rechnungslegung_dialog.dart';

/// Main screen for the Beiträge (invoices) module.
class BeitraegeScreen extends HookConsumerWidget {
  const BeitraegeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Register create action in global registry (Issue 4.1)
    // Deferred via Future to avoid modifying a provider during widget build.
    useEffect(() {
      Future(() {
        ref
            .read(createActionRegistryProvider.notifier)
            .register(
              CreateActionEntry(
                label: 'Rechnungslegung',
                action: (context) => RechnungslegungDialog.show(context),
              ),
            );
      });
      return () => Future(() {
        ref
            .read(createActionRegistryProvider.notifier)
            .unregister('Rechnungslegung');
      });
    }, []);

    final selectedRowId = useState<int?>(null);

    // Stream bemerkung for the selected row
    final bemerkungStream = useMemoized(
      () => selectedRowId.value != null
          ? ref
                .read(beitraegeRepositoryProvider)
                .watchBemerkungForBeitrag(selectedRowId.value!)
          : const Stream<BemerkungData?>.empty(),
      [selectedRowId.value],
    );
    final bemerkungAsync = useStream(bemerkungStream);

    return FeatureScreenScaffold(
      title: 'Beiträge',
      hasSelection: selectedRowId.value != null,
      onCreateNew: () => NeuerBeitragDialog.show(context),
      onDeleteSelection: () async {
        if (selectedRowId.value == null) return;
        final confirm = await AppDialogDeleteAction.showDeleteConfirmation(
          context,
          entityName: 'den ausgewählten Beitrag',
        );
        if (confirm && context.mounted) {
          try {
            await ref
                .read(beitraegeRepositoryProvider)
                .deleteBeitrag(selectedRowId.value!);
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
              entityName: 'Beitrag',
              onSave: (titel, text) => ref
                  .read(bemerkungRepositoryProvider)
                  .saveBemerkung(bemerkungAsync.data?.id, titel, text),
            )
          : null,
      body: BeitragDataGrid(
        onRowSelected: (row) {
          selectedRowId.value = row?.beitrag.id;
        },
      ),
    );
  }
}
