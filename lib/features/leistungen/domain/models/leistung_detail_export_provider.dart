import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../widgets/data_grid_v2/export/export_data_table.dart';
import '../../../export/domain/detail_export_provider.dart';

/// Provides detail export data for a Leistung (service/membership tier).
class LeistungDetailExportProvider implements DetailExportProvider {
  final LeistungItem leistung;
  final PreisItem preis;
  final BemerkungData? bemerkung;

  const LeistungDetailExportProvider({
    required this.leistung,
    required this.preis,
    this.bemerkung,
  });

  @override
  String get entityType => 'leistung';

  @override
  String get title => 'Leistung ${leistung.name}';

  @override
  String? get subtitle => null;

  @override
  ExportDataTable toExportDataTable() {
    final cf = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final rows = <List<String>>[];

    rows.add(['Name', leistung.name]);
    rows.add(['Laufzeit', leistung.laufzeit]);
    rows.add(['Bruttopreis', cf.format(preis.bruttopreis)]);

    // Bemerkung
    if (bemerkung != null) {
      rows.add(['', '']);
      rows.add(['Bemerkung', bemerkung!.titel]);
      if (bemerkung!.textValue != null && bemerkung!.textValue!.isNotEmpty) {
        rows.add(['Bemerkung Text', bemerkung!.textValue!]);
      }
    }

    return ExportDataTable(
      title: title,
      headers: ['Feld', 'Wert'],
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }
}
