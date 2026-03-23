import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:clupdata/core/database/database.dart';
import '../../common_widgets/bemerkung_detail_view.dart';
import '../../common_widgets/feature_screen_scaffold.dart';
import 'widgets/member_data_grid.dart';
import 'widgets/member_edit_dialog.dart';
import 'data/members_repository.dart';
import 'presentation/providers/selected_member_provider.dart';

/// The main view for managing club members.
class MembersScreen extends HookConsumerWidget {
  /// Creates the members screen.
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the persisted selected member ID from the provider
    final persistedSelectedId = ref.watch(selectedMemberIdProvider);

    // Local state to hold the currently selected row ID
    final selectedRowId = useState<int?>(persistedSelectedId);

    // Sync local state with provider when provider changes
    useEffect(() {
      selectedRowId.value = persistedSelectedId;
      return null;
    }, [persistedSelectedId]);

    final bemerkungStream = useMemoized(
      () => selectedRowId.value != null
          ? ref
                .read(membersRepositoryProvider)
                .watchBemerkungForMember(selectedRowId.value!)
          : const Stream<BemerkungData?>.empty(),
      [selectedRowId.value],
    );
    final bemerkungAsync = useStream(bemerkungStream);

    return FeatureScreenScaffold(
      title: 'Mitglieder',
      hasSelection: selectedRowId.value != null,
      onCreateNew: () => MemberEditDialog.show(context),
      onDeleteSelection: () async {
        if (selectedRowId.value == null) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Wirklich löschen?'),
            content: const Text(
              'Möchten Sie den ausgewählten Datensatz unwiderruflich löschen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          try {
            await ref
                .read(membersRepositoryProvider)
                .deleteMember(selectedRowId.value!);
            // Clear both local state and persisted selection
            selectedRowId.value = null;
            ref.read(selectedMemberIdProvider.notifier).clear();
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
              entityName: 'Mitglied',
              onSave: (titel, text) => ref
                  .read(membersRepositoryProvider)
                  .saveMemberRemark(
                    selectedRowId.value!,
                    bemerkungAsync.data?.id,
                    titel,
                    text,
                  ),
            )
          : null,
      body: MemberDataGrid(
        initialSelectedId: persistedSelectedId,
        onRowSelected: (row) {
          selectedRowId.value = row?.id;
          // Persist the selection in the provider
          ref.read(selectedMemberIdProvider.notifier).select(row?.id);
        },
      ),
    );
  }
}
