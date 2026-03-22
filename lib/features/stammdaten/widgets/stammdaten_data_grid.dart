import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid_v2/app_data_grid_v2.dart';
import '../../../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../../../../core/database/database.dart';
import '../presentation/providers/stammdaten_list_provider.dart';
import 'stammdaten_edit_dialog.dart';

class StammdatenDataGrid extends HookConsumerWidget {
  final void Function(StammdatenItem? row)? onRowSelected;

  const StammdatenDataGrid({
    super.key,
    this.onRowSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(stammdatenGridRowsProvider);

    // Columns based on structur.md:
    // bezeichnung, wert, kategorie, schluessel, beschreibung (hidden)
    final columns = useMemoized<List<DataGridColumnConfig<StammdatenItem>>>(() {
      return [
        DataGridColumnConfig<StammdatenItem>(
          field: 'bezeichnung',
          title: 'Bezeichnung',
          valueExtractor: (row) => row.bezeichnung,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<StammdatenItem>(
          field: 'wert',
          title: 'Wert',
          valueExtractor: (row) => row.wert ?? '',
          type: PlutoColumnType.text(), // Stored as text, parsed dynamically
        ),
        DataGridColumnConfig<StammdatenItem>(
          field: 'kategorie',
          title: 'Kategorie',
          valueExtractor: (row) => row.kategorie,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<StammdatenItem>(
          field: 'schluessel',
          title: 'Schlüssel',
          valueExtractor: (row) => row.schluessel,
          type: PlutoColumnType.text(),
        ),
      ];
    }, []);

    return rowsAsync.when(
      data: (rowData) {
        return AppDataGridV2<StammdatenItem>(
          items: rowData,
          columnConfigs: columns,
          toSearchString: (row) {
            return [
              row.bezeichnung,
              row.wert ?? '',
              row.kategorie,
              row.schluessel,
            ].where((e) => e.isNotEmpty).join(' ').toLowerCase();
          },
          toJson: (row) => row.toJson(),
          fromJson: StammdatenItem.fromJson,
          onRowSelected: onRowSelected,
          detailModalBuilder: (row, fieldName) {
             final schluessel = row.schluessel;
             StammdatenEditDialog.show(context, schluessel: schluessel);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}

