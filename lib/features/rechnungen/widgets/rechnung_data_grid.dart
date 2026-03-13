import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid/app_data_grid.dart';
import '../../../../widgets/data_grid/sort_column_config.dart';
import '../data/rechnungen_repository.dart';
import '../utils/rechnung_status_colors.dart';
import 'rechnung_edit_dialog.dart';

/// DataGrid for Rechnungen (invoices). One row per Rechnung, colour-coded by status.
class RechnungDataGrid extends HookConsumerWidget {
  final void Function(PlutoRow? row)? onRowSelected;

  const RechnungDataGrid({super.key, this.onRowSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rechnungenAsync = ref.watch(rechnungenListProvider);
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final currencyFormatter = NumberFormat.currency(
      locale: 'de_DE',
      symbol: '€',
    );

    // Columns per structur.md
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
          title: 'Kunde',
          field: 'kunde_name',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 250,
        ),
        PlutoColumn(
          title: 'Datum',
          field: 'datum',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 120,
        ),
        PlutoColumn(
          title: 'Betrag (Brutto)',
          field: 'betrag_brutto',
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          enableFilterMenuItem: true,
          enableSorting: true,
          width: 140,
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
            final status = rendererContext.cell.value as String? ?? '';
            final color = rechnungStatusColor(status);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: color.withAlpha((255 * 0.5).round())),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: rechnungStatusTextColor(status),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ];
    }, []);

    final sortConfigs = useMemoized<List<SortColumnConfig>>(() {
      return columns
          .where((c) => c.enableSorting)
          .map((c) => SortColumnConfig(field: c.field, label: c.title))
          .toList();
    }, [columns]);

    final rowData = rechnungenAsync.value ?? [];
    final plutoRows = useMemoized<List<PlutoRow>>(() {
      return rowData.map((rd) {
        return PlutoRow(
          cells: {
            'id': PlutoCell(value: rd.rechnung.id),
            'rechnungsnummer': PlutoCell(value: rd.rechnung.rechnungsnummer),
            'kunde_name': PlutoCell(value: rd.kundeName),
            'datum': PlutoCell(value: dateFormatter.format(rd.rechnung.datum)),
            'betrag_brutto': PlutoCell(
              value: currencyFormatter.format(rd.rechnung.betragBrutto),
            ),
            'status': PlutoCell(value: rd.rechnung.status),
          },
        );
      }).toList();
    }, [rowData]);

    return rechnungenAsync.when(
      data: (_) => AppDataGrid(
        rows: plutoRows,
        columns: columns,
        sortableColumns: sortConfigs,
        toSearchString: (row) {
          return [
                row.cells['rechnungsnummer']?.value,
                row.cells['kunde_name']?.value,
                row.cells['status']?.value,
                row.cells['datum']?.value,
              ]
              .where((e) => e != null && e.toString().isNotEmpty)
              .join(' ')
              .toLowerCase();
        },
        onRowSelected: onRowSelected,
        onRowActivated: (row, fieldName) {
          final rechnungId = row.cells['id']?.value as int;
          RechnungEditDialog.show(
            context,
            rechnungId: rechnungId,
            initialFocusField: fieldName,
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
