import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';

import 'beitraege_table.dart';
import 'rechnung_table.dart';

/// Dokumentierte Mahnstufen je Forderung (Beitrag oder Rechnung).
///
/// Stufen: 1 = Zahlungserinnerung, 2 = 1. Mahnung, 3 = 2. Mahnung,
/// 4 = Inkasso/Eskalation. Genau ein Beleg-Bezug ist gesetzt (XOR).
@DataClassName('Mahnung')
@TableIndex(name: 'idx_mahnung_beitrag', columns: {#beitragId})
@TableIndex(name: 'idx_mahnung_rechnung', columns: {#rechnungId})
@TableIndex(name: 'idx_mahnung_uuid', columns: {#uuid}, unique: true)
class Mahnungen extends Table {
  @override
  String get tableName => 'mahnung';

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

  /// 1 = Zahlungserinnerung, 2 = 1. Mahnung, 3 = 2. Mahnung, 4 = Inkasso.
  IntColumn get stufe => integer()();

  DateTimeColumn get datum => dateTime()();

  /// Mahngebühr in Euro.
  RealColumn get gebuehr => real().withDefault(const Constant(0.0))();

  /// Offener Betrag zum Mahnzeitpunkt (Forderung).
  RealColumn get forderung => real()();

  TextColumn get bemerkung => text().nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK ((beitrag_id IS NULL) != (rechnung_id IS NULL))',
  ];
}
