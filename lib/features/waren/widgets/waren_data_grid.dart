import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid/app_data_grid.dart';
import '../../../../widgets/data_grid/sort_column_config.dart';
import '../models/waren_row_data.dart';
import '../widgets/waren_edit_dialog.dart';
import '../presentation/providers/waren_list_provider.dart';

class WarenDataGrid extends HookConsumerWidget {
  const WarenDataGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch data
    final rowsAsync = ref.watch(warenGridRowsProvider);

    // 2. Define Columns per structur.md (Waren)
    final columns = useMemoized<List<PlutoColumn>>(() {
      final currencyFormatter = NumberFormat.currency(locale: 'de_DE', symbol: '€');

      return [
        PlutoColumn(
          title: 'Bezeichnung',
          field: 'bezeichnung',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Kategorie',
          field: 'kategorie',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Bestand',
          field: 'bestand',
          type: PlutoColumnType.number(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          textAlign: PlutoColumnTextAlign.right,
          titleTextAlign: PlutoColumnTextAlign.right,
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
          enableSorting: false,
          textAlign: PlutoColumnTextAlign.right,
          titleTextAlign: PlutoColumnTextAlign.right,
          formatter: (value) => currencyFormatter.format(value),
        ),
        PlutoColumn(
          title: 'Aktiv',
          field: 'aktiv',
          type: PlutoColumnType.text(),
// Unused in PlutoGrid 8.x, boolean columns are handled differently
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          formatter: (value) => value == true ? 'Ja' : 'Nein',
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

    // 4. Map Rows
    final rowData = rowsAsync.value ?? [];
    final plutoRows = useMemoized<List<PlutoRow>>(() {
      return rowData.map((w) {
        return PlutoRow(
          cells: {
             'id': PlutoCell(value: w.id), // Hidden data
             'bezeichnung': PlutoCell(value: w.bezeichnung),
             'kategorie': PlutoCell(value: w.kategorie ?? ''),
             'bestand': PlutoCell(value: w.bestand),
             'bruttopreis': PlutoCell(value: w.bruttopreis),
             'nettopreis': PlutoCell(value: w.nettopreis), 
             'aktiv': PlutoCell(value: w.aktiv), 
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
                row.cells['bezeichnung']?.value,
                row.cells['kategorie']?.value,
              ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
           }, 
           onCreateNew: () => WarenEditDialog.show(context),
           onRowActivated: (row, fieldName) {
              final wareId = row.cells['id']?.value as int;
              WarenEditDialog.show(context, wareId: wareId, initialFocusField: fieldName);
           }
         );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
