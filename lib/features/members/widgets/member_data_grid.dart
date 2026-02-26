
import 'package:pluto_grid/pluto_grid.dart';
import '../../../widgets/data_grid/app_data_grid.dart';
import '../../../widgets/data_grid/sort_column_config.dart';

class MemberDataGrid extends AppDataGrid {
  MemberDataGrid({
    super.key,
    required super.rows,
  }) : super(
          columns: _buildColumns(),
          sortableColumns: _buildSortableColumns(),
        );

  @override
  String toSearchString(PlutoRow row) {
    return [
      row.cells['name']?.value,
      row.cells['vorname']?.value,
      row.cells['ort']?.value,
      row.cells['plz']?.value,
      row.cells['email']?.value,
      row.cells['telefon1']?.value,
      row.cells['telefon2']?.value,
      row.cells['leistung_name']?.value,
      row.cells['vertrag_laufzeit_von']?.value,
      row.cells['vertrag_laufzeit_bis']?.value,
      row.cells['vertrag_kontierung']?.value,
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ').toLowerCase();
  }

  static List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(
        title: 'Name',
        field: 'name',
        type: PlutoColumnType.text(),
        width: 150,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'Vorname',
        field: 'vorname',
        type: PlutoColumnType.text(),
        width: 130,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'Ort',
        field: 'ort',
        type: PlutoColumnType.text(),
        width: 120,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'Telefon',
        field: 'telefon1',
        type: PlutoColumnType.text(),
        width: 130,
        enableSorting: false,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'E-Mail',
        field: 'email',
        type: PlutoColumnType.text(),
        width: 180,
        enableSorting: false,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'Vertragsart',
        field: 'leistung_name',
        type: PlutoColumnType.text(),
        width: 150,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'Laufzeit von',
        field: 'vertrag_laufzeit_von',
        type: PlutoColumnType.date(format: 'dd.MM.yyyy', headerFormat: 'MMMM yyyy'),
        width: 120,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'Laufzeit bis',
        field: 'vertrag_laufzeit_bis',
        type: PlutoColumnType.date(format: 'dd.MM.yyyy', headerFormat: 'MMMM yyyy'),
        width: 120,
        enableFilterMenuItem: true,
      ),
      PlutoColumn(
        title: 'Alter',
        field: 'alter',
        type: PlutoColumnType.number(),
        width: 70,
        enableFilterMenuItem: false,
      ),
      // Hidden columns for search and sort mechanisms
      PlutoColumn(title: 'PLZ', field: 'plz', type: PlutoColumnType.text(), hide: true, enableFilterMenuItem: false),
      PlutoColumn(title: 'Telefon 2', field: 'telefon2', type: PlutoColumnType.text(), hide: true, enableFilterMenuItem: false),
      PlutoColumn(title: 'Kontierung', field: 'vertrag_kontierung', type: PlutoColumnType.date(format: 'dd.MM.yyyy'), hide: true, enableFilterMenuItem: false),
      PlutoColumn(title: 'ID', field: 'id', type: PlutoColumnType.number(), hide: true, enableFilterMenuItem: false),
    ];
  }

  static List<SortColumnConfig> _buildSortableColumns() {
    return [
      SortColumnConfig(field: 'name', label: 'Name', enabled: true, ascending: true, priority: 0),
      SortColumnConfig(field: 'vorname', label: 'Vorname', enabled: false, ascending: true, priority: 1),
      SortColumnConfig(field: 'vertrag_kontierung', label: 'Kontierung', enabled: false, ascending: false, priority: 2),
      SortColumnConfig(field: 'vertrag_laufzeit_von', label: 'Laufzeit von', enabled: false, ascending: true, priority: 3),
      SortColumnConfig(field: 'vertrag_laufzeit_bis', label: 'Laufzeit bis', enabled: false, ascending: true, priority: 4),
      SortColumnConfig(field: 'leistung_name', label: 'Vertragsart', enabled: false, ascending: true, priority: 5),
    ];
  }
}
