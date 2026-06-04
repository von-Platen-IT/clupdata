import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';

/// Defines the structure for the `stammdaten` table.
/// Key/value configuration store. Contains global settings like MwSt rate, file paths, app config.
@DataClassName('StammdatenItem')
@TableIndex(
  name: 'idx_stammdaten_schluessel',
  columns: {#schluessel},
  unique: true,
)
@TableIndex(name: 'idx_stammdaten_kategorie', columns: {#kategorie})
@TableIndex(name: 'idx_stammdaten_uuid', columns: {#uuid}, unique: true)
class Stammdaten extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  TextColumn get schluessel => text().withLength(max: 100).unique()();
  TextColumn get wert => text().nullable()();
  TextColumn get typ => text()(); // enum: string, integer, float, boolean, date
  TextColumn get kategorie =>
      text()(); // enum: finanzen, programm, firma, druck, sonstiges
  TextColumn get bezeichnung => text().withLength(max: 200)();
  TextColumn get beschreibung => text().nullable().withLength(max: 500)();
  IntColumn get aenderbar => integer().withDefault(
    const Constant(1),
  )(); // 1 = user may edit, 0 = read-only
  BoolColumn get systemPflicht => boolean().withDefault(
    const Constant(false),
  )(); // 1 = mandatory record (cannot be deleted)
}
