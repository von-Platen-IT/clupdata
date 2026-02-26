import 'package:drift/drift.dart';

/// Defines the structure for the `stammdaten` table.
/// Key/value configuration store. Contains global settings like MwSt rate, file paths, app config.
@DataClassName('StammdatenItem')
class Stammdaten extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get schluessel => text().withLength(max: 100).unique()();
  TextColumn get wert => text().nullable()();
  TextColumn get typ => text()(); // enum: string, number, boolean, date
  TextColumn get kategorie => text()(); // enum: finanzen, programm, firma, druck, sonstiges
  TextColumn get bezeichnung => text().withLength(max: 200)();
  TextColumn get beschreibung => text().nullable().withLength(max: 500)();
  IntColumn get aenderbar => integer().withDefault(const Constant(1))(); // 1 = user may edit, 0 = read-only
}
