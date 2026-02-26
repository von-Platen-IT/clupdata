import 'package:drift/drift.dart';

/// Defines the structure for the `bemerkung` table.
/// Generic note/remark entity reused across all tables via FK.
class Bemerkung extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titel => text().withLength(max: 200)();
  TextColumn get textValue => text().named('text').nullable().withLength(max: 10000)();
  DateTimeColumn get datumErstellt => dateTime().withDefault(currentDateAndTime)();
}
