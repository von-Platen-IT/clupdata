import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../common_widgets/forms/app_text_field.dart';
import '../../../widgets/data_grid/app_data_table.dart';
import '../../../widgets/data_grid/data_table_column.dart';
import 'presentation/providers/members_list_provider.dart';
import 'data/members_repository.dart';
import 'models/member_row_data.dart';
import 'widgets/member_edit_dialog.dart';

/// The main view for managing club members.
class MembersScreen extends HookConsumerWidget {
  /// Creates the members screen.
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(membersGridRowsProvider);
    final selectedMemberId = useState<int?>(null);

    final columns = useMemoized(() {
      final dateFormat = DateFormat('dd.MM.yyyy');
      String formatDate(DateTime? date) => date != null ? dateFormat.format(date) : '';

      return <DataTableColumn<MemberRowData>>[
        DataTableColumn(
          label: 'Name',
          valueExtractor: (m) => m.name,
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Vorname',
          valueExtractor: (m) => m.vorname,
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Ort',
          valueExtractor: (m) => m.ort ?? '',
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Telefon',
          valueExtractor: (m) => m.telefon1 ?? '',
          sortable: false,
          flex: 2,
        ),
        DataTableColumn(
          label: 'E-Mail',
          valueExtractor: (m) => m.email ?? '',
          sortable: false,
          flex: 3,
        ),
        DataTableColumn(
          label: 'Leistung',
          valueExtractor: (m) => m.leistungName ?? '',
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Laufzeit von',
          valueExtractor: (m) => formatDate(m.vertragLaufzeitVon),
          sortExtractor: (m) => m.vertragLaufzeitVon,
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Laufzeit bis',
          valueExtractor: (m) => formatDate(m.vertragLaufzeitBis),
          sortExtractor: (m) => m.vertragLaufzeitBis,
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Alter',
          valueExtractor: (m) => m.alter?.toString() ?? '',
          sortExtractor: (m) => m.alter,
          sortable: true,
          flex: 1,
          alignment: Alignment.centerRight,
        ),
      ];
    }, []);

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
      body: Material(
        child: Column(
          children: [
            Expanded(
              child: rowsAsync.when(
                data: (rows) {
                  final selectedItem = rows.where((r) => r.id == selectedMemberId.value).firstOrNull;
                  
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: AppDataTable<MemberRowData>(
                      items: rows,
                      columns: columns,
                      selectedItem: selectedItem,
                      searchFilter: (item, query) {
                        final searchStr = [
                          item.name, item.vorname, item.ort, item.plz, item.email,
                          item.telefon1, item.telefon2, item.leistungName,
                          item.vertragLaufzeitVon != null ? DateFormat('dd.MM.yyyy').format(item.vertragLaufzeitVon!) : '',
                          item.vertragLaufzeitBis != null ? DateFormat('dd.MM.yyyy').format(item.vertragLaufzeitBis!) : null,
                          item.vertragKontierung != null ? DateFormat('dd.MM.yyyy').format(item.vertragKontierung!) : null,
                        ].whereType<String>().where((e) => e.isNotEmpty).join(' ').toLowerCase();
                        return searchStr.contains(query);
                      },
                      onRowSelected: (row) {
                        selectedMemberId.value = row.id;
                      },
                      onRowDoubleTap: (row) async {
                        final repo = ref.read(membersRepositoryProvider);
                        final member = await repo.getMemberById(row.id);
                        if (member != null && context.mounted) {
                          MemberEditDialog.show(context, member: member);
                        }
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
              ),
            ),
            if (selectedMemberId.value != null)
              _BemerkungDetailView(memberId: selectedMemberId.value!),
          ],
        ),
      ),
    );
  }
}

class _BemerkungDetailView extends HookConsumerWidget {
  final int memberId;

  const _BemerkungDetailView({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bemerkungAsync = ref.watch(bemerkungForMemberProvider(memberId));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          )
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: bemerkungAsync.when(
        data: (bemerkung) {
          final titleCtrl = useTextEditingController(text: bemerkung?.titel ?? '');
          final textCtrl = useTextEditingController(text: bemerkung?.textValue ?? '');
          
          // Update controllers if data changes (e.g. on new selection)
          useEffect(() {
            titleCtrl.text = bemerkung?.titel ?? '';
            textCtrl.text = bemerkung?.textValue ?? '';
            return null;
          }, [bemerkung]);

          final isLoadingAsync = useState(false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // Take only necessary space at the bottom
            children: [
              Text('Bemerkung', style: Theme.of(context).textTheme.titleMedium),
              const Gap(8),
              AppTextField(
                controller: titleCtrl,
                label: 'Bemerkung Titel',
              ),
              const Gap(8),
              AppTextField(
                controller: textCtrl,
                label: 'Bemerkung Text',
                maxLines: 4,
              ),
              const Gap(16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: isLoadingAsync.value ? null : () async {
                    isLoadingAsync.value = true;
                    try {
                      final repo = ref.read(membersRepositoryProvider);
                      await repo.saveMemberRemark(memberId, bemerkung?.id, titleCtrl.text.trim(), textCtrl.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bemerkung gespeichert')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
                      }
                    } finally {
                      if (context.mounted) {
                        isLoadingAsync.value = false;
                      }
                    }
                  },
                  icon: isLoadingAsync.value
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                  label: const Text('Speichern'),
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Fehler beim Laden der Bemerkung: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
