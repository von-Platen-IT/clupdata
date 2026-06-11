import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../widgets/data_grid_v2/export/export_data_table.dart';
import '../../../export/domain/detail_export_provider.dart';
import '../models/beitrag_status.dart';

/// Provides detail export data for a Beitrag (contribution invoice).
///
/// Includes contribution data, member/leistung names, status history,
/// and optional Bemerkung.
class BeitragDetailExportProvider implements DetailExportProvider {
  final Beitrag beitrag;
  final String mitgliedName;
  final String leistungName;
  final double? bruttopreis;
  final BemerkungData? bemerkung;
  final List<BeitragStatusVerlaufData>? statusVerlauf;

  const BeitragDetailExportProvider({
    required this.beitrag,
    required this.mitgliedName,
    required this.leistungName,
    this.bruttopreis,
    this.bemerkung,
    this.statusVerlauf,
  });

  @override
  String get entityType => 'beitrag';

  @override
  String get title => 'Beitrag ${beitrag.rechnungsnummer}';

  @override
  String? get subtitle => mitgliedName;

  @override
  ExportDataTable toExportDataTable() {
    final df = DateFormat('dd.MM.yyyy');
    final cf = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final rows = <List<String>>[];

    // Grunddaten
    rows.add(['Rechnungsnummer', beitrag.rechnungsnummer]);
    rows.add(['Mitglied', mitgliedName]);
    rows.add(['Leistung', leistungName]);
    if (bruttopreis != null) {
      rows.add(['Betrag (brutto)', cf.format(bruttopreis!)]);
    }

    // Status
    final statusEnum = BeitragStatus.fromString(beitrag.status);
    rows.add(['Status', statusEnum.label]);
    rows.add(['Kontiert am', df.format(beitrag.kontiertAm)]);
    if (beitrag.abrechnungsZeitraum != null) {
      rows.add([
        'Abrechnungszeitraum',
        df.format(beitrag.abrechnungsZeitraum!),
      ]);
    }
    rows.add(['Statusdatum', df.format(beitrag.statusDatum)]);

    // Status-Verlauf
    if (statusVerlauf != null && statusVerlauf!.isNotEmpty) {
      rows.add(['', '']);
      rows.add(['-- Status-Verlauf --', '']);
      for (final eintrag in statusVerlauf!) {
        final statusLabel = BeitragStatus.fromString(eintrag.status).label;
        final timestamp = DateFormat(
          'dd.MM.yyyy HH:mm',
        ).format(eintrag.geaendertAm);
        rows.add([timestamp, '$statusLabel — ${eintrag.bemerkung}']);
      }
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
