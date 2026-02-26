import 'package:drift/drift.dart';
import 'bemerkung_table.dart';
import 'leistung_table.dart';

/// Defines the structure for the `mitglied` table.
/// Main member entity.
@DataClassName('Mitglied')
class Mitglieds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get anrede => text().nullable()(); // enum: Herr, Frau, Divers, Keine
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get vorname => text().withLength(max: 100)();
  TextColumn get plz => text().nullable().withLength(max: 10)();
  TextColumn get ort => text().nullable().withLength(max: 100)();
  TextColumn get telefon1 => text().nullable().withLength(max: 50)();
  TextColumn get telefon2 => text().nullable().withLength(max: 50)();
  TextColumn get email => text().nullable().withLength(max: 200)();
  TextColumn get geschlecht => text().nullable()(); // enum: maennlich, weiblich, divers
  DateTimeColumn get geboren => dateTime().nullable()();
  IntColumn get leistungId => integer().nullable().references(Leistung, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get vertragKontierung => dateTime().nullable()();
  DateTimeColumn get vertragLaufzeitVon => dateTime().nullable()();
  DateTimeColumn get vertragLaufzeitBis => dateTime().nullable()();
  IntColumn get bemerkungId => integer().nullable().references(Bemerkung, #id, onDelete: KeyAction.setNull)();

  // drift indexes are defined in AppDatabase or using @TableIndex but we configure them centrally in the Database class definition to conform with the structured setup.
}
