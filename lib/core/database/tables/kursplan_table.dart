import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';
import 'bemerkung_table.dart';

/// Defines the structure for the `kursplan` table.
///
/// A course schedule plan with a validity period. Multiple plans can exist
/// for different time ranges (at least one week each). `gueltigVon` and
/// `gueltigBis` are normalized to Mondays (start of week) when saved.
@DataClassName('KursplanItem')
@TableIndex(name: 'idx_kursplan_gueltig', columns: {#gueltigVon, #gueltigBis})
@TableIndex(name: 'idx_kursplan_uuid', columns: {#uuid}, unique: true)
class Kursplan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  TextColumn get name => text().withLength(max: 100)();

  /// First valid week (normalized to Monday).
  DateTimeColumn get gueltigVon => dateTime()();

  /// Last valid week (normalized to Monday). NULL = valid indefinitely.
  DateTimeColumn get gueltigBis => dateTime().nullable()();
  IntColumn get bemerkungId => integer().nullable().references(
    Bemerkung,
    #id,
    onDelete: KeyAction.setNull,
  )();
}
