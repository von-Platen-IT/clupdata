import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid/app_data_grid.dart';
import '../../../../widgets/data_grid/sort_column_config.dart';
import '../models/leistung_row_data.dart';
import '../widgets/leistung_edit_dialog.dart';
import '../presentation/providers/leistungen_list_provider.dart';

class LeistungDataGrid extends HookConsumerWidget {
  const LeistungDataGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch data
    final rowsAsync = ref.watch(leistungenGridRowsProvider);

    // 2. Define Columns per structur.md
    final columns = useMemoized<List<PlutoColumn>>(() {
      final currencyFormatter = NumberFormat.currency(locale: 'de_DE', symbol: '€');

      return [
        PlutoColumn(
          title: 'Name',
          field: 'name',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Laufzeit',
          field: 'laufzeit',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Brutto (€)',
          field: 'bruttopreis',
          type: PlutoColumnType.number(),
          enableEditingMode: false,
          enableFilterMenuItem: false,
          enableSorting: true,
          textAlign: PlutoColumnTextAlign.right,
          titleTextAlign: PlutoColumnTextAlign.right,
          formatter: (value) => currencyFormatter.format(value),
        ),
        PlutoColumn(
          title: 'Netto (€)',
          field: 'nettopreis',
          type: PlutoColumnType.number(),
          enableEditingMode: false, // Computed field based on MwSt
          enableFilterMenuItem: false,
          enableSorting: false, // Rule says Sort:False, Filter:False
          textAlign: PlutoColumnTextAlign.right,
          titleTextAlign: PlutoColumnTextAlign.right,
          formatter: (value) => currencyFormatter.format(value),
        ),
      ];
    }, []);

    // 3. Define Sortconfigs
    final sortConfigs = useMemoized<List<SortColumnConfig>>(() {
      return columns
          .where((c) => c.enableSorting)
          .map((c) => SortColumnConfig(field: c.field, label: c.title))
          .toList();
    }, [columns]);

    // 4. Map Rows (cached to avoid rebuilding PlutoRows on every build)
    final rowData = rowsAsync.value ?? [];
    final plutoRows = useMemoized<List<PlutoRow>>(() {
      return rowData.map((l) {
        return PlutoRow(
          cells: {
             'id': PlutoCell(value: l.id), // Hidden data
             'name': PlutoCell(value: l.name),
             'laufzeit': PlutoCell(value: l.laufzeit),
             'bruttopreis': PlutoCell(value: l.bruttopreis),
             'nettopreis': PlutoCell(value: l.nettopreis), 
          }
        );
      }).toList();
    }, [rowData]);

    return rowsAsync.when(
      data: (_) {
         return AppDataGrid(
           rows: plutoRows, 
           columns: columns, 
           sortableColumns: sortConfigs, 
           toSearchString: (row) {
              return [
                row.cells['name']?.value,
                row.cells['laufzeit']?.value,
              ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
           }, 
           onRowActivated: (row, fieldName) async {
              final leistungId = row.cells['id']?.value as int;

              // Fetch full details (incl. preis/bemerkung) before opening dialog
              final detailsList = await ref.read(watchLeistungenDetailsProvider.future);
              final details = detailsList.where((d) => d.leistung.id == leistungId).firstOrNull;

              if (context.mounted && details != null) {
                 LeistungEditDialog.show(context, details: details, initialFocusField: fieldName);
              }
           }
         );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
