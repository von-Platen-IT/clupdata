import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../widgets/data_grid/app_data_grid.dart';
import '../../../widgets/data_grid/sort_column_config.dart';

class MemberDataGrid extends AppDataGrid {
  MemberDataGrid({super.key})
      : super(
          columns: _buildColumns(),
          rows: _buildMockRows(),
          sortableColumns: _buildSortableColumns(),
        );

  @override
  String toSearchString(PlutoRow row) {
    return [
      row.cells['name']?.value?.toString(),
      row.cells['email']?.value?.toString(),
      row.cells['join_date']?.value?.toString(),
      row.cells['contract_type']?.value?.toString(),
    ].where((s) => s != null).join(' ');
  }

  static List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(
        title: 'Name',
        field: 'name',
        type: PlutoColumnType.text(),
        enableFilterMenuItem: true,
        enableSorting: true,
      ),
      PlutoColumn(
        title: 'E-Mail',
        field: 'email',
        type: PlutoColumnType.text(),
        enableFilterMenuItem: true,
        enableSorting: true,
      ),
      PlutoColumn(
        title: 'Beitrittsdatum',
        field: 'join_date',
        type: PlutoColumnType.date(format: 'dd.MM.yyyy', headerFormat: 'MMMM yyyy'),
        enableFilterMenuItem: true,
        enableSorting: true,
      ),
      PlutoColumn(
        title: 'Vertragsart',
        field: 'contract_type',
        type: PlutoColumnType.text(),
        enableFilterMenuItem: true,
        enableSorting: true,
      ),
    ];
  }

  static List<SortColumnConfig> _buildSortableColumns() {
    return [
      SortColumnConfig(field: 'name', label: 'Name', priority: 0),
      SortColumnConfig(field: 'email', label: 'E-Mail', priority: 1),
      SortColumnConfig(field: 'join_date', label: 'Beitrittsdatum', priority: 2),
      SortColumnConfig(field: 'contract_type', label: 'Vertragsart', priority: 3),
    ];
  }

  static List<PlutoRow> _buildMockRows() {
    return [
      PlutoRow(cells: {
        'name': PlutoCell(value: 'Max Mustermann'),
        'email': PlutoCell(value: 'max@example.com'),
        'join_date': PlutoCell(value: '01.01.2023'),
        'contract_type': PlutoCell(value: 'Jahresvertrag'),
      }),
      PlutoRow(cells: {
        'name': PlutoCell(value: 'Anna Schmidt'),
        'email': PlutoCell(value: 'anna@example.com'),
        'join_date': PlutoCell(value: '15.03.2024'),
        'contract_type': PlutoCell(value: 'Monatsvertrag'),
      }),
      PlutoRow(cells: {
        'name': PlutoCell(value: 'Peter Müller'),
        'email': PlutoCell(value: 'peter@example.com'),
        'join_date': PlutoCell(value: '10.11.2023'),
        'contract_type': PlutoCell(value: 'Jahresvertrag'),
      }),
    ];
  }
}
