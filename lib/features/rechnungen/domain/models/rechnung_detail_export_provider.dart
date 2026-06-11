import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../widgets/data_grid_v2/export/export_data_table.dart';
import '../../../export/domain/detail_export_provider.dart';
import '../models/rechnung_status.dart';

/// Provides detail export data for a Rechnung (sales invoice).
///
/// Includes invoice header, positions, totals, and optional Bemerkung.
class RechnungDetailExportProvider implements DetailExportProvider {
  final Rechnung rechnung;
  final List<RechnungPosition> positionen;
  final String kundeName;
  final BemerkungData? bemerkung;

  const RechnungDetailExportProvider({
    required this.rechnung,
    required this.positionen,
    required this.kundeName,
    this.bemerkung,
  });

  @override
  String get entityType => 'rechnung';

  @override
  String get title => 'Rechnung ${rechnung.rechnungsnummer}';

  @override
  String? get subtitle => kundeName;

  @override
  ExportDataTable toExportDataTable() {
    final df = DateFormat('dd.MM.yyyy');
    final cf = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final rows = <List<String>>[];

    // Grunddaten
    rows.add(['Rechnungsnummer', rechnung.rechnungsnummer]);
    rows.add(['Kunde', kundeName]);

    final statusEnum = RechnungStatus.fromString(rechnung.status);
    rows.add(['Status', statusEnum.label]);

    rows.add(['Rechnungsdatum', df.format(rechnung.datum)]);
    rows.add(['Fällig am', df.format(rechnung.faelligAm)]);
    if (rechnung.bezahltAm != null) {
      rows.add(['Bezahlt am', df.format(rechnung.bezahltAm!)]);
    }

    // Positionen
    if (positionen.isNotEmpty) {
      rows.add(['', '']);
      rows.add(['-- Positionen --', '']);
      for (final pos in positionen) {
        final mengeStr = pos.menge == pos.menge.roundToDouble()
            ? '${pos.menge.toInt()}'
            : '${pos.menge}';
        rows.add([
          '${pos.positionNr}. ${pos.bezeichnung}',
          '$mengeStr × ${cf.format(pos.einzelpreisBrutto)} = ${cf.format(pos.gesamtBrutto)}',
        ]);
      }
    }

    // Summen
    rows.add(['', '']);
    rows.add(['-- Summen --', '']);
    rows.add(['Netto', cf.format(rechnung.betragNetto)]);
    rows.add(['MwSt', cf.format(rechnung.betragMwst)]);
    rows.add(['Brutto', cf.format(rechnung.betragBrutto)]);

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
