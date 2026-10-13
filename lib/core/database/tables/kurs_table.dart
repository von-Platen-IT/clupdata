import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';
import 'bemerkung_table.dart';

/// Defines the structure for the `kurs` table.
///
/// Kurstyp/Kursangebot (z. B. „Boxen Erwachsene"). Jeder Kurstyp hat eine
/// eindeutige Farbe für die farbliche Kennzeichnung im Kursplan.
@DataClassName('KursItem')
@TableIndex(name: 'idx_kurs_name', columns: {#name})
@TableIndex(name: 'idx_kurs_uuid', columns: {#uuid}, unique: true)
class Kurs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get kampfsportart => text().withLength(max: 100)();

  /// Hex color `#RRGGBB` – used as background for course blocks in the
  /// schedule view. Stored in the DB so it can be changed without app updates.
  TextColumn get farbe => text().withLength(max: 9)();
  IntColumn get bemerkungId => integer().nullable().references(
    Bemerkung,
    #id,
    onDelete: KeyAction.setNull,
  )();
}
