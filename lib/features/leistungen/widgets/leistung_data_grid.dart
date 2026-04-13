import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid_v2/vpit_data_grid.dart';
import '../../../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../domain/models/leistung_row_data.dart';
import '../widgets/leistung_edit_dialog.dart';
import '../presentation/providers/leistungen_list_provider.dart';
import '../../export/domain/export_config.dart';

class LeistungDataGrid extends HookConsumerWidget {
  final void Function(LeistungRowData? row)? onRowSelected;

  const LeistungDataGrid({super.key, this.onRowSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch data
    final rowsAsync = ref.watch(leistungenGridRowsProvider);

    // 2. Define Columns per structur.md
    final columns = useMemoized<List<DataGridColumnConfig<LeistungRowData>>>(
      () {
        final currencyFormatter = NumberFormat.currency(
          locale: 'de_DE',
          symbol: '€',
        );

        return [
          DataGridColumnConfig<LeistungRowData>(
            field: 'name',
            title: 'Name',
            valueExtractor: (row) => row.name,
            type: PlutoColumnType.text(),
          ),
          DataGridColumnConfig<LeistungRowData>(
            field: 'laufzeit',
            title: 'Laufzeit',
            valueExtractor: (row) => row.laufzeit,
            type: PlutoColumnType.text(),
          ),
          DataGridColumnConfig<LeistungRowData>(
            field: 'bruttopreis',
            title: 'Brutto (€)',
            valueExtractor: (row) => row.bruttopreis,
            type: PlutoColumnType.number(),
            filterable: false,
            formatter: (value) => currencyFormatter.format(value),
          ),
          DataGridColumnConfig<LeistungRowData>(
            field: 'nettopreis',
            title: 'Netto (€)',
            valueExtractor: (row) => row.nettopreis,
            type: PlutoColumnType.number(),
            filterable: false,
            sortable: false,
            formatter: (value) => currencyFormatter.format(value),
          ),
        ];
      },
      [],
    );

    return rowsAsync.when(
      data: (rowData) {
        return VpitDataGrid<LeistungRowData>(
          items: rowData,
          columnConfigs: columns,
          toSearchString: (row) {
            return [
              row.name,
              row.laufzeit,
            ].where((e) => e.isNotEmpty).join(' ').toLowerCase();
          },
          toJson: (row) => row.toJson(),
          fromJson: LeistungRowData.fromJson,
          onRowSelected: onRowSelected,
          detailModalBuilder: (row, fieldName) async {
            final leistungId = row.id;

            // Fetch full details (incl. preis/bemerkung) before opening dialog
            final detailsList = await ref.read(
              watchLeistungenDetailsProvider.future,
            );
            final details = detailsList
                .where((d) => d.leistung.id == leistungId)
                .firstOrNull;

            if (context.mounted && details != null) {
              LeistungEditDialog.show(
                context,
                details: details,
                initialFocusField: fieldName,
              );
            }
          },
          exportConfig: const ExportConfig(
            entityType: 'leistung',
            title: 'Leistungen',
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
