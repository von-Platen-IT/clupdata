import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid/app_data_grid.dart';
import '../../../../widgets/data_grid/sort_column_config.dart';
import '../../../../core/database/database.dart';
import '../presentation/providers/stammdaten_list_provider.dart';
import 'stammdaten_edit_dialog.dart';

class StammdatenDataGrid extends HookConsumerWidget {
  final void Function(PlutoRow? row)? onRowSelected;

  const StammdatenDataGrid({
    super.key,
    this.onRowSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(stammdatenGridRowsProvider);

    // Columns based on structur.md:
    // bezeichnung, wert, kategorie, schluessel, beschreibung (hidden)
    final columns = useMemoized<List<PlutoColumn>>(() {
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
          title: 'Wert',
          field: 'wert',
          type: PlutoColumnType.text(), // Stored as text, parsed dynamically
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
          title: 'Schlüssel',
          field: 'schluessel',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
      ];
    }, []);

    final sortConfigs = useMemoized<List<SortColumnConfig>>(() {
      return columns
          .where((c) => c.enableSorting)
          .map((c) => SortColumnConfig(field: c.field, label: c.title))
          .toList();
    }, [columns]);

    // Fast mapping inside useMemoized so we don't rebuild PlutoRows on every frame
    final List<StammdatenItem> rowData = rowsAsync.value ?? const [];
    final plutoRows = useMemoized<List<PlutoRow>>(() {
      return rowData.map((s) {
        return PlutoRow(
          cells: {
             // System fields used for edit mapping but not necessarily displayed
            'id': PlutoCell(value: s.id),
            'typ': PlutoCell(value: s.typ),
            'aenderbar': PlutoCell(value: s.aenderbar),
            'beschreibung': PlutoCell(value: s.beschreibung ?? ''),
            // Visible grid columns
            'bezeichnung': PlutoCell(value: s.bezeichnung),
            'wert': PlutoCell(value: s.wert ?? ''),
            'kategorie': PlutoCell(value: s.kategorie),
            'schluessel': PlutoCell(value: s.schluessel),
          },
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
               row.cells['wert']?.value,
               row.cells['kategorie']?.value,
               row.cells['schluessel']?.value,
             ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
          },
          onRowSelected: onRowSelected,
          onRowActivated: (row, fieldName) {
             final schluessel = row.cells['schluessel']?.value as String;
             StammdatenEditDialog.show(context, schluessel: schluessel);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
