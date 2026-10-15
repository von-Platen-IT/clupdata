import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';

import 'beitraege_table.dart';
import 'rechnung_table.dart';

/// Zahlungseingänge zu Beiträgen oder Rechnungen (auch Teilzahlungen und
/// Gutschrift-Ausgleiche). Genau ein Beleg-Bezug ist gesetzt (XOR).
///
/// Der Belegstatus wird aus `SUM(zahlungen)` vs. Forderung abgeleitet
/// (Saldo-Prinzip, siehe `plans/rechnungsstellung-redesign.md`).
@DataClassName('Zahlung')
@TableIndex(name: 'idx_zahlung_beitrag', columns: {#beitragId})
@TableIndex(name: 'idx_zahlung_rechnung', columns: {#rechnungId})
@TableIndex(name: 'idx_zahlung_uuid', columns: {#uuid}, unique: true)
class Zahlungen extends Table {
  @override
  String get tableName => 'zahlung';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();

  // Genau EINES von beitragId/rechnungId wird gesetzt (CHECK unten).
  IntColumn get beitragId => integer().nullable().references(
    Beitraege,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get rechnungId => integer().nullable().references(
    Rechnungen,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Positiv = Zahlungseingang, negativ = Gutschrift-Ausgleich.
  RealColumn get betrag => real()();

  /// Zahlungsdatum.
  DateTimeColumn get datum => dateTime()();

  /// Zahlungsart: bar, karte, lastschrift, ueberweisung, sonstiges.
  TextColumn get zahlungsart => text()();

  TextColumn get bemerkung => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK ((beitrag_id IS NULL) != (rechnung_id IS NULL))',
  ];
}
