import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/core/providers/create_action_provider.dart';
import '../../common_widgets/app_dialog_delete_action.dart';
import '../../common_widgets/bemerkung_detail_view.dart';
import '../../common_widgets/feature_screen_scaffold.dart';
import 'widgets/leistung_data_grid.dart';
import 'widgets/leistung_edit_dialog.dart';
import 'data/leistungen_repository.dart';

class LeistungenScreen extends HookConsumerWidget {
  const LeistungenScreen({super.key});

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
                label: 'Leistung',
                action: (context) => LeistungEditDialog.show(context),
              ),
            );
      });
      return () => Future(() {
        ref.read(createActionRegistryProvider.notifier).unregister('Leistung');
      });
    }, []);

    // State to hold the currently selected row ID for the delete button
    final selectedRowId = useState<int?>(null);

    final bemerkungStream = useMemoized(
      () => selectedRowId.value != null
          ? ref
                .read(leistungenRepositoryProvider)
                .watchBemerkungForLeistung(selectedRowId.value!)
          : const Stream<BemerkungData?>.empty(),
      [selectedRowId.value],
    );
    final bemerkungAsync = useStream(bemerkungStream);

    return FeatureScreenScaffold(
      title: 'Leistungen',
      hasSelection: selectedRowId.value != null,
      onCreateNew: () => LeistungEditDialog.show(context),
      onDeleteSelection: () async {
        if (selectedRowId.value == null) return;
        final confirm = await AppDialogDeleteAction.showDeleteConfirmation(
          context,
          entityName: 'den ausgewählten Datensatz',
        );
        if (confirm && context.mounted) {
          try {
            await ref
                .read(leistungenRepositoryProvider)
                .deleteLeistung(selectedRowId.value!);
            selectedRowId.value = null; // Clear selection
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
              entityName: 'Leistung',
              onSave: (titel, text) => ref
                  .read(leistungenRepositoryProvider)
                  .saveLeistungRemark(
                    selectedRowId.value!,
                    bemerkungAsync.data?.id,
                    titel,
                    text,
                  ),
            )
          : null,
      body: LeistungDataGrid(
        onRowSelected: (row) {
          selectedRowId.value = row?.id;
        },
      ),
    );
  }
}
