import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';

import '../../../widgets/data_grid/app_data_table.dart';
import '../../../widgets/data_grid/data_table_column.dart';
import '../../../common_widgets/forms/app_text_field.dart';
import 'presentation/providers/leistungen_list_provider.dart';
import 'data/leistungen_repository.dart';
import 'models/leistung_row_data.dart';
import 'widgets/leistung_edit_dialog.dart';

class LeistungenScreen extends HookConsumerWidget {
  const LeistungenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leistungenAsync = ref.watch(leistungenGridRowsProvider);
    final selectedLeistungId = useState<int?>(null);

    final columns = useMemoized<List<DataTableColumn<LeistungRowData>>>(() {
      final currencyFormatter = NumberFormat.currency(locale: 'de_DE', symbol: '€');
      return [
        DataTableColumn(
          label: 'Name',
          valueExtractor: (l) => l.name,
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Laufzeit',
          valueExtractor: (l) => l.laufzeit,
          sortable: true,
          flex: 1,
        ),
        DataTableColumn(
          label: 'Brutto',
          valueExtractor: (l) => currencyFormatter.format(l.bruttopreis),
          sortExtractor: (l) => l.bruttopreis,
          sortable: true,
          flex: 1,
          alignment: Alignment.centerRight,
        ),
        DataTableColumn(
          label: 'Netto',
          valueExtractor: (l) => currencyFormatter.format(l.nettopreis),
          sortExtractor: (l) => l.nettopreis,
          sortable: true,
          flex: 1,
          alignment: Alignment.centerRight,
        ),
      ];
    }, []);

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
      body: leistungenAsync.when(
        data: (rows) {
          return Column(
            children: [
              Expanded(
                child: AppDataTable<LeistungRowData>(
                  items: rows,
                  columns: columns,
                  searchFilter: (item, query) {
                    final searchStr = [
                      item.name, item.laufzeit,
                    ].where((e) => e.isNotEmpty).join(' ').toLowerCase();
                    return searchStr.contains(query);
                  },
                  onRowSelected: (row) {
                    selectedLeistungId.value = row.id;
                  },
                  onRowDoubleTap: (row) async {
                    final detailsList = await ref.read(watchLeistungenDetailsProvider.future);
                    final details = detailsList.firstWhere((d) => d.leistung.id == row.id);
                    if (context.mounted) {
                      LeistungEditDialog.show(context, details: details);
                    }
                  },
                ),
              ),
              if (selectedLeistungId.value != null)
                _BemerkungDetailView(
                  leistungId: selectedLeistungId.value!,
                  rows: rows,
                ),
            ],
          );
        },
        error: (err, stack) => Center(child: Text('Fehler: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _BemerkungDetailView extends HookConsumerWidget {
  final int leistungId;
  final List<LeistungRowData> rows;

  const _BemerkungDetailView({required this.leistungId, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleCtrl = useTextEditingController();
    final textCtrl = useTextEditingController();
    final isLoadingAsync = useState(false);

    // Watch the specific row's bemerkung info
    final detailsAsync = ref.watch(watchLeistungenDetailsProvider);
    final detailsList = detailsAsync.value ?? [];
    final details = detailsList.where((d) => d.leistung.id == leistungId).firstOrNull;
    final bemerkung = details?.bemerkung;

    useEffect(() {
      titleCtrl.text = bemerkung?.titel ?? '';
      textCtrl.text = bemerkung?.textValue ?? '';
      return null;
    }, [bemerkung]);

    if (details == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Bemerkung', style: Theme.of(context).textTheme.titleMedium),
          const Gap(8),
          AppTextField(controller: titleCtrl, label: 'Bemerkung Titel'),
          const Gap(8),
          AppTextField(controller: textCtrl, label: 'Bemerkung Text', maxLines: 4),
          const Gap(16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: isLoadingAsync.value ? null : () async {
                isLoadingAsync.value = true;
                try {
                  final repo = ref.read(leistungenRepositoryProvider);
                  await repo.saveLeistungRemark(leistungId, bemerkung?.id, titleCtrl.text.trim(), textCtrl.text.trim());
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
      ),
    );
  }
}
