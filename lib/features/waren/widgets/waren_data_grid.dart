import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid_v2/vpit_data_grid.dart';
import '../../../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../domain/models/waren_row_data.dart';
import '../widgets/waren_edit_dialog.dart';
import '../presentation/providers/waren_list_provider.dart';
import '../../export/domain/export_config.dart';

/// Concrete DataGrid implementation for [WarenRowData] using [VpitDataGrid].
///
/// Fetches data via Riverpod, defines columns per structur.md (Section 4.2,
/// Screen: Waren), and delegates detail editing to [WarenEditDialog].
class WarenDataGrid extends HookConsumerWidget {
  /// Called when the selected row changes. Provides the [WarenRowData]
  /// of the selected row, or `null` if selection is cleared.
  final void Function(WarenRowData? item)? onRowSelected;

  const WarenDataGrid({super.key, this.onRowSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(warenGridRowsProvider);

    // ── Column definitions per structur.md (exact order) ──────────────────
    final columnConfigs = useMemoized<List<DataGridColumnConfig<WarenRowData>>>(
      () {
        final currencyFormatter = NumberFormat.currency(
          locale: 'de_DE',
          symbol: '€',
        );

        return [
          DataGridColumnConfig<WarenRowData>(
            field: 'bezeichnung',
            title: 'Bezeichnung',
            type: PlutoColumnType.text(),
            sortable: true,
            filterable: true,
            valueExtractor: (w) => w.bezeichnung,
          ),
          DataGridColumnConfig<WarenRowData>(
            field: 'kategorie',
            title: 'Kategorie',
            type: PlutoColumnType.text(),
            sortable: true,
            filterable: true,
            valueExtractor: (w) => w.kategorie ?? '',
          ),
          DataGridColumnConfig<WarenRowData>(
            field: 'bestand',
            title: 'Bestand',
            type: PlutoColumnType.number(),
            sortable: true,
            filterable: true,
            textAlign: PlutoColumnTextAlign.right,
            titleTextAlign: PlutoColumnTextAlign.right,
            valueExtractor: (w) => w.bestand,
          ),
          DataGridColumnConfig<WarenRowData>(
            field: 'bruttopreis',
            title: 'Brutto (€)',
            type: PlutoColumnType.number(),
            sortable: true,
            filterable: false,
            textAlign: PlutoColumnTextAlign.right,
            titleTextAlign: PlutoColumnTextAlign.right,
            formatter: (value) => currencyFormatter.format(value),
            valueExtractor: (w) => w.bruttopreis,
          ),
          DataGridColumnConfig<WarenRowData>(
            field: 'nettopreis',
            title: 'Netto (€)',
            type: PlutoColumnType.number(),
            editable: false, // Computed field
            sortable: false,
            filterable: false,
            textAlign: PlutoColumnTextAlign.right,
            titleTextAlign: PlutoColumnTextAlign.right,
            formatter: (value) => currencyFormatter.format(value),
            valueExtractor: (w) => w.nettopreis,
          ),
          DataGridColumnConfig<WarenRowData>(
            field: 'aktiv',
            title: 'Aktiv',
            type: PlutoColumnType.text(),
            sortable: true,
            filterable: true,
            formatter: (value) => value == true ? 'Ja' : 'Nein',
            valueExtractor: (w) => w.aktiv,
          ),
        ];
      },
      [],
    );

    // ── Data ──────────────────────────────────────────────────────────────
    final rowData = rowsAsync.value ?? [];

    return rowsAsync.when(
      data: (_) {
        return VpitDataGrid<WarenRowData>(
          items: rowData,
          columnConfigs: columnConfigs,
          toSearchString: (w) {
            return [
              w.bezeichnung,
              w.kategorie,
            ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
          },
          toJson: (w) => {
            'id': w.id,
            'bezeichnung': w.bezeichnung,
            'kategorie': w.kategorie,
            'bestand': w.bestand,
            'bruttopreis': w.bruttopreis,
            'nettopreis': w.nettopreis,
            'aktiv': w.aktiv,
          },
          fromJson: (json) => WarenRowData(
            id: json['id'] as int,
            bezeichnung: json['bezeichnung'] as String,
            kategorie: json['kategorie'] as String?,
            bruttopreis: (json['bruttopreis'] as num).toDouble(),
            nettopreis: (json['nettopreis'] as num).toDouble(),
            bestand: json['bestand'] as int,
            mindestbestand: 0,
            aktiv: json['aktiv'] as bool,
            erstelltAm: DateTime.now(),
            aktualisiertAm: DateTime.now(),
          ),
          onRowSelected: onRowSelected,
          detailModalBuilder: (item, focusedColumnId) {
            WarenEditDialog.show(
              context,
              wareId: item.id,
              initialFocusField: focusedColumnId,
            );
          },
          exportConfig: const ExportConfig(entityType: 'ware', title: 'Waren'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}
