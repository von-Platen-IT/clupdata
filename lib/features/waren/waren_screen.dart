import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';

import '../../../widgets/data_grid/app_data_table.dart';
import '../../../widgets/data_grid/data_table_column.dart';
import '../../../common_widgets/forms/app_text_field.dart';
import 'presentation/providers/waren_list_provider.dart';
import 'data/waren_repository.dart';
import 'models/waren_row_data.dart';
import 'widgets/waren_edit_dialog.dart';

class WarenScreen extends HookConsumerWidget {
  const WarenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warenAsync = ref.watch(warenGridRowsProvider);
    final selectedWareId = useState<int?>(null);

    final columns = useMemoized<List<DataTableColumn<WarenRowData>>>(() {
      final currencyFormatter = NumberFormat.currency(locale: 'de_DE', symbol: '€');
      return [
        DataTableColumn(
          label: 'Bezeichnung',
          valueExtractor: (w) => w.bezeichnung,
          sortable: true,
          flex: 2,
        ),
        DataTableColumn(
          label: 'Kategorie',
          valueExtractor: (w) => w.kategorie ?? '',
          sortable: true,
          flex: 1,
        ),
        DataTableColumn(
          label: 'Bestand',
          valueExtractor: (w) => w.bestand.toString(),
          sortable: true,
          flex: 1,
          alignment: Alignment.centerRight,
        ),
        DataTableColumn(
          label: 'Brutto',
          valueExtractor: (w) => currencyFormatter.format(w.bruttopreis),
          sortExtractor: (w) => w.bruttopreis,
          sortable: true,
          flex: 1,
          alignment: Alignment.centerRight,
        ),
        DataTableColumn(
          label: 'Netto',
          valueExtractor: (w) => currencyFormatter.format(w.nettopreis),
          sortExtractor: (w) => w.nettopreis,
          sortable: false, // Netto computed on the fly, typically we sort by brutto
          flex: 1,
          alignment: Alignment.centerRight,
        ),
        DataTableColumn(
          label: 'Aktiv',
          valueExtractor: (w) => w.aktiv ? 'Ja' : 'Nein',
          sortable: true,
          flex: 1,
          cellBuilder: (row) => Icon(
            row.aktiv ? Icons.check_circle : Icons.cancel,
            color: row.aktiv ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
      ];
    }, []);

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
      body: warenAsync.when(
        data: (rows) {
          return Column(
            children: [
              Expanded(
                child: AppDataTable<WarenRowData>(
                  items: rows,
                  columns: columns,
                  searchFilter: (item, query) {
                    final searchValues = [
                      item.bezeichnung,
                      item.kategorie,
                      item.hersteller,
                      item.herstellerArtikelnr,
                    ].whereType<String>().where((e) => e.isNotEmpty).join(' ').toLowerCase();
                    return searchValues.contains(query);
                  },
                  onRowSelected: (row) {
                    selectedWareId.value = row.id;
                  },
                  onRowDoubleTap: (row) async {
                    final detailsList = await ref.read(watchWarenDetailsProvider.future);
                    final details = detailsList.firstWhere((d) => d.ware.id == row.id);
                    if (context.mounted) {
                      WarenEditDialog.show(context, details: details);
                    }
                  },
                ),
              ),
              if (selectedWareId.value != null)
                _BemerkungDetailView(
                  wareId: selectedWareId.value!,
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
  final int wareId;
  final List<WarenRowData> rows;

  const _BemerkungDetailView({required this.wareId, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleCtrl = useTextEditingController();
    final textCtrl = useTextEditingController();
    final isLoadingAsync = useState(false);

    final detailsAsync = ref.watch(watchWarenDetailsProvider);
    final detailsList = detailsAsync.value ?? [];
    final details = detailsList.where((d) => d.ware.id == wareId).firstOrNull;
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
                  final repo = ref.read(warenRepositoryProvider);
                  await repo.saveWareRemark(wareId, bemerkung?.id, titleCtrl.text.trim(), textCtrl.text.trim());
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
