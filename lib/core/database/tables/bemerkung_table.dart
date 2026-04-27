import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';

/// Defines the structure for the `bemerkung` table.
/// Generic note/remark entity reused across all tables via FK.
@TableIndex(name: 'idx_bemerkung_datum', columns: {#datumErstellt})
@TableIndex(name: 'idx_bemerkung_uuid', columns: {#uuid}, unique: true)
class Bemerkung extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  TextColumn get titel => text().withLength(max: 200)();
  TextColumn get textValue =>
      text().named('text').nullable().withLength(max: 10000)();
  DateTimeColumn get datumErstellt =>
      dateTime().withDefault(currentDateAndTime)();
}
