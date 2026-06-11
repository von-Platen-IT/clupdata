import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../widgets/data_grid_v2/export/export_data_table.dart';
import '../../../export/domain/detail_export_provider.dart';

/// Provides detail export data for a Mitglied (member) record.
///
/// Includes all fields from the member form: Person, Kontakt, Vertrag,
/// Preis, and Bemerkung.
class MemberDetailExportProvider implements DetailExportProvider {
  final Mitglied mitglied;
  final String? leistungName;
  final double? bruttopreis;
  final BemerkungData? bemerkung;

  const MemberDetailExportProvider({
    required this.mitglied,
    this.leistungName,
    this.bruttopreis,
    this.bemerkung,
  });

  @override
  String get entityType => 'mitglied';

  @override
  String get title => 'Mitglied ${mitglied.name}, ${mitglied.vorname}';

  @override
  String? get subtitle => mitglied.ort;

  @override
  ExportDataTable toExportDataTable() {
    final df = DateFormat('dd.MM.yyyy');
    final cf = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final rows = <List<String>>[];

    // Person
    if (mitglied.anrede != null) rows.add(['Anrede', mitglied.anrede!]);
    rows.add(['Name', mitglied.name]);
    rows.add(['Vorname', mitglied.vorname]);
    if (mitglied.geboren != null) {
      rows.add(['Geburtsdatum', df.format(mitglied.geboren!)]);
    }
    if (mitglied.geschlecht != null) {
      rows.add(['Geschlecht', mitglied.geschlecht!]);
    }

    // Kontakt
    if (mitglied.strasse != null) rows.add(['Straße', mitglied.strasse!]);
    if (mitglied.hausnummer != null) {
      rows.add(['Hausnummer', mitglied.hausnummer!]);
    }
    if (mitglied.plz != null) rows.add(['PLZ', mitglied.plz!]);
    if (mitglied.ort != null) rows.add(['Ort', mitglied.ort!]);
    if (mitglied.telefon1 != null) rows.add(['Telefon 1', mitglied.telefon1!]);
    if (mitglied.telefon2 != null) rows.add(['Telefon 2', mitglied.telefon2!]);
    if (mitglied.email != null) rows.add(['E-Mail', mitglied.email!]);

    // Vertrag
    if (leistungName != null) rows.add(['Vertragsart', leistungName!]);
    if (bruttopreis != null) {
      rows.add(['Beitrag (brutto)', cf.format(bruttopreis!)]);
    }
    if (mitglied.vertragKontierung != null) {
      rows.add(['Kontierung', df.format(mitglied.vertragKontierung!)]);
    }
    if (mitglied.vertragLaufzeitVon != null) {
      rows.add(['Laufzeit von', df.format(mitglied.vertragLaufzeitVon!)]);
    }
    if (mitglied.vertragLaufzeitBis != null) {
      rows.add(['Laufzeit bis', df.format(mitglied.vertragLaufzeitBis!)]);
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
