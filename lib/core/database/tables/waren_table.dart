import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';
import 'bemerkung_table.dart';

@DataClassName('WarenItem')
@TableIndex(name: 'idx_waren_bezeichnung', columns: {#bezeichnung})
@TableIndex(name: 'idx_waren_kategorie', columns: {#kategorie})
@TableIndex(name: 'idx_waren_aktiv', columns: {#aktiv})
@TableIndex(name: 'idx_waren_uuid', columns: {#uuid}, unique: true)
class Waren extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  TextColumn get bezeichnung => text().withLength(max: 200)();
  TextColumn get beschreibung => text().withLength(max: 2000).nullable()();
  TextColumn get kategorie => text().withLength(max: 100).nullable()();
  TextColumn get groesse => text().withLength(max: 50).nullable()();
  TextColumn get farbe => text().withLength(max: 50).nullable()();
  TextColumn get geschlecht =>
      text().nullable()(); // Enum:[Unisex, Herren, Damen, Kinder]
  TextColumn get material => text().withLength(max: 100).nullable()();
  RealColumn get einkaufspreis => real().nullable()();
  RealColumn get bruttopreis => real()();
  IntColumn get bestand => integer().withDefault(const Constant(0))();
  IntColumn get mindestbestand => integer().withDefault(const Constant(0))();
  TextColumn get lieferant => text().withLength(max: 200).nullable()();
  TextColumn get hersteller => text().withLength(max: 200).nullable()();
  TextColumn get herstellerArtikelnr =>
      text().withLength(max: 100).nullable()();
  RealColumn get gewichtKg => real().nullable()();
  TextColumn get einheit => text().withLength(max: 50).nullable()();
  TextColumn get bildUrl => text().withLength(max: 500).nullable()();
  BoolColumn get aktiv => boolean().withDefault(const Constant(true))();
  DateTimeColumn get erstelltAm => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get aktualisiertAm =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get bemerkungId => integer().nullable().references(
    Bemerkung,
    #id,
    onDelete: KeyAction.setNull,
  )();
}
