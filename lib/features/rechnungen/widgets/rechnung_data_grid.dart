import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid_v2/vpit_data_grid.dart';
import '../../../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../data/rechnungen_repository.dart';
import '../utils/rechnung_status_colors.dart';
import 'rechnung_edit_dialog.dart';
import '../../export/domain/export_config.dart';

/// DataGrid for Rechnungen (invoices). One row per Rechnung, colour-coded by status.
class RechnungDataGrid extends HookConsumerWidget {
  final void Function(RechnungRowData? row)? onRowSelected;

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
    final columns = useMemoized<List<DataGridColumnConfig<RechnungRowData>>>(() {
      return [
        DataGridColumnConfig<RechnungRowData>(
          field: 'rechnungsnummer',
          title: 'Rechnungs-Nr.',
          valueExtractor: (row) => row.rechnung.rechnungsnummer,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<RechnungRowData>(
          field: 'kunde_name',
          title: 'Kunde',
          valueExtractor: (row) => row.kundeName,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<RechnungRowData>(
          field: 'datum',
          title: 'Datum',
          valueExtractor: (row) => dateFormatter.format(row.rechnung.datum),
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<RechnungRowData>(
          field: 'betrag_brutto',
          title: 'Betrag (Brutto)',
          valueExtractor: (row) => row.rechnung.betragBrutto,
          type: PlutoColumnType.number(),
          filterable: false,
          formatter: (value) => currencyFormatter.format(value),
        ),
        DataGridColumnConfig<RechnungRowData>(
          field: 'status',
          title: 'Status',
          valueExtractor: (row) => row.rechnung.status,
          type: PlutoColumnType.text(),
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

    return rechnungenAsync.when(
      data: (rowData) {
        return VpitDataGrid<RechnungRowData>(
          items: rowData,
          columnConfigs: columns,
          toSearchString: (row) {
            return [
              row.rechnung.rechnungsnummer,
              row.kundeName,
              row.rechnung.status,
              dateFormatter.format(row.rechnung.datum),
            ].where((e) => e.isNotEmpty).join(' ').toLowerCase();
          },
          toJson: (row) => row.toJson(),
          fromJson: RechnungRowData.fromJson,
          onRowSelected: onRowSelected,
          detailModalBuilder: (row, fieldName) {
            final rechnungId = row.rechnung.id;
            RechnungEditDialog.show(
              context,
              rechnungId: rechnungId,
              initialFocusField: fieldName,
            );
          },
          exportConfig: const ExportConfig(
            entityType: 'rechnung',
            title: 'Rechnungen',
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}

