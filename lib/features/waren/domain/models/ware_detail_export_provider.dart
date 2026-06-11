import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../widgets/data_grid_v2/export/export_data_table.dart';
import '../../../export/domain/detail_export_provider.dart';

/// Provides detail export data for a Ware (product/merchandise).
class WareDetailExportProvider implements DetailExportProvider {
  final WarenItem ware;
  final BemerkungData? bemerkung;

  const WareDetailExportProvider({required this.ware, this.bemerkung});

  @override
  String get entityType => 'ware';

  @override
  String get title => 'Ware ${ware.bezeichnung}';

  @override
  String? get subtitle => ware.kategorie;

  @override
  ExportDataTable toExportDataTable() {
    final cf = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final rows = <List<String>>[];

    // Allgemein
    rows.add(['Bezeichnung', ware.bezeichnung]);
    if (ware.kategorie != null) rows.add(['Kategorie', ware.kategorie!]);
    if (ware.beschreibung != null) {
      rows.add(['Beschreibung', ware.beschreibung!]);
    }

    // Eigenschaften
    if (ware.groesse != null) rows.add(['Größe', ware.groesse!]);
    if (ware.farbe != null) rows.add(['Farbe', ware.farbe!]);
    if (ware.geschlecht != null) rows.add(['Geschlecht', ware.geschlecht!]);
    if (ware.material != null) rows.add(['Material', ware.material!]);

    // Preise
    if (ware.einkaufspreis != null) {
      rows.add(['Einkaufspreis', cf.format(ware.einkaufspreis!)]);
    }
    rows.add(['Bruttopreis', cf.format(ware.bruttopreis)]);

    // Bestand
    rows.add(['Bestand', '${ware.bestand}']);
    rows.add(['Mindestbestand', '${ware.mindestbestand}']);

    // Logistik
    if (ware.lieferant != null) rows.add(['Lieferant', ware.lieferant!]);
    if (ware.hersteller != null) rows.add(['Hersteller', ware.hersteller!]);
    if (ware.herstellerArtikelnr != null) {
      rows.add(['Hersteller-Artikelnr.', ware.herstellerArtikelnr!]);
    }

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
