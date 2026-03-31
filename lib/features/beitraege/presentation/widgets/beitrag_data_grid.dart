import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid_v2/vpit_data_grid.dart';
import '../../../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../../domain/models/beitrag_status.dart';
import '../../providers/beitraege_repository.dart';
import '../dialogs/beitrag_edit_dialog.dart';
import 'status_badge.dart';
import '../../../export/domain/export_config.dart';

/// DataGrid for Beiträge (invoices). One row per Beitrag, colour-coded by status.
class BeitragDataGrid extends HookConsumerWidget {
  final void Function(BeitragRowData? row)? onRowSelected;

  const BeitragDataGrid({super.key, this.onRowSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beitraegeAsync = ref.watch(beitraegeListProvider);
    final dateFormatter = DateFormat('dd.MM.yyyy');

    // Columns per structur.md screen_beitrag_list
    final columns = useMemoized<List<DataGridColumnConfig<BeitragRowData>>>(() {
      return [
        DataGridColumnConfig<BeitragRowData>(
          field: 'rechnungsnummer',
          title: 'Rechnungs-Nr.',
          valueExtractor: (row) => row.beitrag.rechnungsnummer,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<BeitragRowData>(
          field: 'mitglied_name',
          title: 'Mitglied',
          valueExtractor: (row) => row.mitgliedName,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<BeitragRowData>(
          field: 'leistung_name',
          title: 'Leistung',
          valueExtractor: (row) => row.leistungName,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<BeitragRowData>(
          field: 'kontiert_am',
          title: 'Kontiert am',
          valueExtractor: (row) => dateFormatter.format(row.beitrag.kontiertAm),
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<BeitragRowData>(
          field: 'status',
          title: 'Status',
          valueExtractor: (row) => row.beitrag.status,
          type: PlutoColumnType.text(),
          renderer: (rendererContext) {
            final statusValue = rendererContext.cell.value as String? ?? '';
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: StatusBadge.fromString(statusValue),
            );
          },
        ),
        DataGridColumnConfig<BeitragRowData>(
          field: 'status_datum',
          title: 'Statusdatum',
          valueExtractor: (row) => dateFormatter.format(row.beitrag.statusDatum),
          type: PlutoColumnType.text(),
        ),
      ];
    }, []);

    return beitraegeAsync.when(
      data: (rowData) {
        return VpitDataGrid<BeitragRowData>(
          items: rowData,
          columnConfigs: columns,
          toSearchString: (row) {
            return [
              row.beitrag.rechnungsnummer,
              row.mitgliedName,
              row.leistungName,
              row.beitrag.status,
              dateFormatter.format(row.beitrag.kontiertAm),
            ].where((e) => e.isNotEmpty).join(' ').toLowerCase();
          },
          toJson: (row) => row.toJson(),
          fromJson: BeitragRowData.fromJson,
          onRowSelected: onRowSelected,
          detailModalBuilder: (row, fieldName) {
            final beitragId = row.beitrag.id;
            BeitragEditDialog.show(
              context,
              beitragId: beitragId,
              initialFocusField: fieldName,
            );
          },
          exportConfig: const ExportConfig(
            entityType: 'beitrag',
            title: 'Beiträge',
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}

