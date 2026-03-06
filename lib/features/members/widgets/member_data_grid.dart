import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid/app_data_grid.dart';
import '../../../../widgets/data_grid/sort_column_config.dart';
import '../models/member_row_data.dart';
import '../widgets/member_edit_dialog.dart';
import '../presentation/providers/members_list_provider.dart';

class MemberDataGrid extends HookConsumerWidget {
  final void Function(PlutoRow? row)? onRowSelected;

  const MemberDataGrid({
    super.key,
    this.onRowSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(membersGridRowsProvider);

    // Columns based on structur.md:
    // name, vorname, ort, telefon1, email, leistung_name, beitrag, vertrag_laufzeit_von, vertrag_laufzeit_bis, alter
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
          title: 'Vorname',
          field: 'vorname',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Ort',
          field: 'ort',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Telefon',
          field: 'telefon1',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: false,
        ),
        PlutoColumn(
          title: 'E-Mail',
          field: 'email',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: false,
        ),
        PlutoColumn(
          title: 'Vertragsart',
          field: 'leistung_name',
          type: PlutoColumnType.text(),
          enableEditingMode: false, // from lookup
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Beitrag',
          field: 'beitrag',
          type: PlutoColumnType.number(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          textAlign: PlutoColumnTextAlign.right,
          titleTextAlign: PlutoColumnTextAlign.right,
          formatter: (value) => (value as num?) != null && value != 0 ? currencyFormatter.format(value) : '',
        ),
        PlutoColumn(
          title: 'Laufzeit von',
          field: 'vertrag_laufzeit_von',
          type: PlutoColumnType.date(format: 'dd.MM.yyyy'),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Laufzeit bis',
          field: 'vertrag_laufzeit_bis',
          type: PlutoColumnType.date(format: 'dd.MM.yyyy'),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
        ),
        PlutoColumn(
          title: 'Alter',
          field: 'alter',
          type: PlutoColumnType.number(),
          enableEditingMode: false, // computed
          enableFilterMenuItem: false,
          enableSorting: true,
          textAlign: PlutoColumnTextAlign.right,
          titleTextAlign: PlutoColumnTextAlign.right,
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
    final rowData = rowsAsync.value ?? [];
    final plutoRows = useMemoized<List<PlutoRow>>(() {
      final dateFormat = DateFormat('yyyy-MM-dd'); // For sorting internally, displayed parsed
      return rowData.map((m) {
        return PlutoRow(
          cells: {
            // Include ID for reference, but it's not a column
            'id': PlutoCell(value: m.id), 
            'name': PlutoCell(value: m.name),
            'vorname': PlutoCell(value: m.vorname),
            'ort': PlutoCell(value: m.ort ?? ''),
            'telefon1': PlutoCell(value: m.telefon1 ?? ''),
            'email': PlutoCell(value: m.email ?? ''),
            'leistung_name': PlutoCell(value: m.leistungName ?? ''),
            'beitrag': PlutoCell(value: m.beitrag ?? 0.0),
            'vertrag_laufzeit_von': PlutoCell(value: m.vertragLaufzeitVon != null ? dateFormat.format(m.vertragLaufzeitVon!) : ''),
            'vertrag_laufzeit_bis': PlutoCell(value: m.vertragLaufzeitBis != null ? dateFormat.format(m.vertragLaufzeitBis!) : ''),
            'alter': PlutoCell(value: m.alter ?? 0),
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
               row.cells['name']?.value,
               row.cells['vorname']?.value,
               row.cells['ort']?.value,
               row.cells['telefon1']?.value,
               row.cells['email']?.value,
               row.cells['leistung_name']?.value,
             ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
          },
          onRowSelected: onRowSelected,
          onRowActivated: (row, fieldName) {
             final memberId = row.cells['id']?.value as int;
             MemberEditDialog.show(context, memberId: memberId, initialFocusField: fieldName);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
