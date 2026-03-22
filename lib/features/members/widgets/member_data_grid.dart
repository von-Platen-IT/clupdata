import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid_v2/app_data_grid_v2.dart';
import '../../../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../models/member_row_data.dart';
import '../widgets/member_edit_dialog.dart';
import '../presentation/providers/members_list_provider.dart';

class MemberDataGrid extends HookConsumerWidget {
  final void Function(MemberRowData? row)? onRowSelected;

  const MemberDataGrid({super.key, this.onRowSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(membersGridRowsProvider);

    // Columns based on structur.md:
    // name, vorname, ort, telefon1, email, leistung_name, beitrag
    final columns = useMemoized<List<DataGridColumnConfig<MemberRowData>>>(() {
      final currencyFormatter = NumberFormat.currency(
        locale: 'de_DE',
        symbol: '€',
      );

      return [
        DataGridColumnConfig<MemberRowData>(
          field: 'name',
          title: 'Name',
          valueExtractor: (row) => row.name,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<MemberRowData>(
          field: 'vorname',
          title: 'Vorname',
          valueExtractor: (row) => row.vorname,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<MemberRowData>(
          field: 'ort',
          title: 'Ort',
          valueExtractor: (row) => row.ort,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<MemberRowData>(
          field: 'telefon1',
          title: 'Telefon',
          valueExtractor: (row) => row.telefon1,
          type: PlutoColumnType.text(),
          sortable: false,
        ),
        DataGridColumnConfig<MemberRowData>(
          field: 'email',
          title: 'E-Mail',
          valueExtractor: (row) => row.email,
          type: PlutoColumnType.text(),
          sortable: false,
        ),
        DataGridColumnConfig<MemberRowData>(
          field: 'leistung_name',
          title: 'Vertragsart',
          valueExtractor: (row) => row.leistungName,
          type: PlutoColumnType.text(),
        ),
        DataGridColumnConfig<MemberRowData>(
          field: 'beitrag',
          title: 'Beitrag',
          valueExtractor: (row) => row.beitrag,
          type: PlutoColumnType.number(),
          formatter: (value) => (value as num?) != null && value != 0
              ? currencyFormatter.format(value)
              : '',
        ),
      ];
    }, []);

    return rowsAsync.when(
      data: (rowData) {
        return AppDataGridV2<MemberRowData>(
          items: rowData,
          columnConfigs: columns,
          toSearchString: (row) {
            return [
              row.name,
              row.vorname,
              row.ort,
              row.telefon1,
              row.email,
              row.leistungName,
            ].where((e) => e != null && e.toString().isNotEmpty).join(' ').toLowerCase();
          },
          toJson: (row) => row.toJson(),
          fromJson: MemberRowData.fromJson,
          onRowSelected: onRowSelected,
          detailModalBuilder: (row, fieldName) {
            final memberId = row.id;
            MemberEditDialog.show(
              context,
              memberId: memberId,
              initialFocusField: fieldName,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler beim Laden: $err')),
    );
  }
}

