import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';

import 'bemerkung_table.dart';
import 'leistung_table.dart';
import 'mitglied_table.dart';
import 'preis_table.dart';

@DataClassName('Beitrag')
@TableIndex(
  name: 'idx_beitrag_rechnungsnummer',
  columns: {#rechnungsnummer},
  unique: true,
)
@TableIndex(name: 'idx_beitrag_mitglied', columns: {#mitgliedId})
@TableIndex(name: 'idx_beitrag_status', columns: {#status})
@TableIndex(name: 'idx_beitrag_uuid', columns: {#uuid}, unique: true)
class Beitraege extends Table {
  @override
  String get tableName => 'beitrag';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  IntColumn get mitgliedId =>
      integer().references(Mitglieds, #id, onDelete: KeyAction.restrict)();
  IntColumn get leistungId =>
      integer().references(Leistung, #id, onDelete: KeyAction.restrict)();
  IntColumn get preisId => integer().nullable().references(
    Preis,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get rechnungsnummer =>
      text().withLength(min: 1, max: 100).unique()();

  // Status: kontiert, offen, bezahlt, angemahnt, storniert, inkasso
  TextColumn get status => text()();

  // Das Datum an dem der Beitrag erstellt wurde (kontiert)
  DateTimeColumn get kontiertAm => dateTime()();
  // Der Abrechnungszeitraum (z.B. 1.3.2026 für März 2026) zur Duplikat-Prüfung
  // Nur befüllt bei automatischer Rechnungslegung, null bei manuellen Beiträgen
  DateTimeColumn get abrechnungsZeitraum => dateTime().nullable()();
  DateTimeColumn get statusDatum => dateTime()();

  IntColumn get bemerkungId => integer().nullable().references(
    Bemerkung,
    #id,
    onDelete: KeyAction.setNull,
  )();
}
