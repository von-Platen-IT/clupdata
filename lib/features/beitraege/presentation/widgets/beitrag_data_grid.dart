import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid/app_data_grid.dart';
import '../../../../widgets/data_grid/sort_column_config.dart';
import '../../domain/models/beitrag_status.dart';
import '../../providers/beitraege_repository.dart';
import '../dialogs/beitrag_edit_dialog.dart';
import 'status_badge.dart';

/// DataGrid for Beiträge (invoices). One row per Beitrag, colour-coded by status.
class BeitragDataGrid extends HookConsumerWidget {
  final void Function(PlutoRow? row)? onRowSelected;

  const BeitragDataGrid({super.key, this.onRowSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beitraegeAsync = ref.watch(beitraegeListProvider);
    final dateFormatter = DateFormat('dd.MM.yyyy');

    // Columns per structur.md screen_beitrag_list
    final columns = useMemoized<List<PlutoColumn>>(() {
      return [
        PlutoColumn(
          title: 'Rechnungs-Nr.',
          field: 'rechnungsnummer',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 150,
        ),
        PlutoColumn(
          title: 'Mitglied',
          field: 'mitglied_name',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 200,
        ),
        PlutoColumn(
          title: 'Leistung',
          field: 'leistung_name',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 180,
        ),
        PlutoColumn(
          title: 'Kontiert am',
          field: 'kontiert_am',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 120,
        ),
        PlutoColumn(
          title: 'Status',
          field: 'status',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 120,
          renderer: (rendererContext) {
            final statusValue = rendererContext.cell.value as String? ?? '';
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: StatusBadge.fromString(statusValue),
            );
          },
        ),
        PlutoColumn(
          title: 'Statusdatum',
          field: 'status_datum',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 120,
        ),
      ];
    }, []);

    final sortConfigs = useMemoized<List<SortColumnConfig>>(() {
      return columns
          .where((c) => c.enableSorting)
          .map((c) => SortColumnConfig(field: c.field, label: c.title))
          .toList();
    }, [columns]);

    final rowData = beitraegeAsync.value ?? [];
    final plutoRows = useMemoized<List<PlutoRow>>(() {
      return rowData.map((rd) {
        return PlutoRow(
          cells: {
            'id': PlutoCell(value: rd.beitrag.id),
            'rechnungsnummer': PlutoCell(value: rd.beitrag.rechnungsnummer),
            'mitglied_name': PlutoCell(value: rd.mitgliedName),
            'leistung_name': PlutoCell(value: rd.leistungName),
            'kontiert_am': PlutoCell(
              value: dateFormatter.format(rd.beitrag.kontiertAm),
            ),
            'status': PlutoCell(value: rd.beitrag.status),
            'status_datum': PlutoCell(
              value: dateFormatter.format(rd.beitrag.statusDatum),
            ),
          },
        );
      }).toList();
    }, [rowData]);

    return beitraegeAsync.when(
      data: (_) => AppDataGrid(
        rows: plutoRows,
        columns: columns,
        sortableColumns: sortConfigs,
        toSearchString: (row) {
          return [
                row.cells['rechnungsnummer']?.value,
                row.cells['mitglied_name']?.value,
                row.cells['leistung_name']?.value,
                row.cells['status']?.value,
                row.cells['kontiert_am']?.value,
              ]
              .where((e) => e != null && e.toString().isNotEmpty)
              .join(' ')
              .toLowerCase();
        },
        onRowSelected: onRowSelected,
        onRowActivated: (row, fieldName) {
          final beitragId = row.cells['id']?.value as int;
          BeitragEditDialog.show(
            context,
            beitragId: beitragId,
            initialFocusField: fieldName,
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
