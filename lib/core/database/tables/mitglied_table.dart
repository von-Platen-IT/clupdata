import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';
import 'bemerkung_table.dart';
import 'leistung_table.dart';
import 'preis_table.dart';

/// Defines the structure for the `mitglied` table.
/// Main member entity.
@DataClassName('Mitglied')
@TableIndex(name: 'idx_mitglied_name', columns: {#name, #vorname})
@TableIndex(name: 'idx_mitglied_plz_ort', columns: {#plz, #ort})
@TableIndex(name: 'idx_mitglied_leistung', columns: {#leistungId})
@TableIndex(name: 'idx_mitglied_vertrag_von', columns: {#vertragLaufzeitVon})
@TableIndex(name: 'idx_mitglied_vertrag_bis', columns: {#vertragLaufzeitBis})
@TableIndex(name: 'idx_mitglied_geboren', columns: {#geboren})
@TableIndex(name: 'idx_mitglied_uuid', columns: {#uuid}, unique: true)
class Mitglieds extends Table {
  @override
  String get tableName => 'mitglied';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  TextColumn get anrede =>
      text().nullable()(); // enum: Herr, Frau, Divers, Keine
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get vorname => text().withLength(max: 100)();
  TextColumn get plz => text().nullable().withLength(max: 10)();
  TextColumn get ort => text().nullable().withLength(max: 100)();
  TextColumn get strasse => text().nullable().withLength(max: 100)();
  TextColumn get hausnummer => text().nullable().withLength(max: 10)();
  TextColumn get telefon1 => text().nullable().withLength(max: 50)();
  TextColumn get telefon2 => text().nullable().withLength(max: 50)();
  TextColumn get email => text().nullable().withLength(max: 200)();
  DateTimeColumn get geboren => dateTime().nullable()();
  TextColumn get geschlecht =>
      text().nullable()(); // Enum:[maennlich, weiblich, divers]
  IntColumn get leistungId => integer().nullable().references(
    Leistung,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get vertragKontierung => dateTime().nullable()();
  DateTimeColumn get vertragLaufzeitVon => dateTime().nullable()();
  DateTimeColumn get vertragLaufzeitBis => dateTime().nullable()();
  IntColumn get preisId => integer().nullable().references(
    Preis,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get bemerkungId => integer().nullable().references(
    Bemerkung,
    #id,
    onDelete: KeyAction.setNull,
  )();

  // drift indexes are defined in AppDatabase or using @TableIndex but we configure them centrally in the Database class definition to conform with the structured setup.
}
