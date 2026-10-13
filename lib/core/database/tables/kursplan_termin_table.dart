import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';
import 'kurs_table.dart';
import 'kursplan_table.dart';

/// Defines the structure for the `kursplan_termin` table.
///
/// A weekly course appointment inside a [Kursplan] (weekday + times).
/// Deleting a plan cascades and removes all its appointments; a [Kurs]
/// with appointments cannot be deleted (RESTRICT).
@DataClassName('KursplanTermin')
@TableIndex(name: 'idx_kursplan_termin_plan', columns: {#kursplanId})
@TableIndex(name: 'idx_kursplan_termin_kurs', columns: {#kursId})
@TableIndex(name: 'idx_kursplan_termin_uuid', columns: {#uuid}, unique: true)
class KursplanTermine extends Table {
  @override
  String get tableName => 'kursplan_termin';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  IntColumn get kursplanId => integer().references(
    Kursplan,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get kursId =>
      integer().references(Kurs, #id, onDelete: KeyAction.restrict)();

  /// 1 = Monday … 7 = Sunday.
  IntColumn get wochentag => integer()();

  /// Start time, format `HH:mm` (lexicographically sortable).
  TextColumn get startzeit => text().withLength(min: 5, max: 5)();

  /// End time, format `HH:mm`. NULL = open end.
  TextColumn get endezeit => text().nullable().withLength(max: 5)();

  @override
  List<String> get customConstraints => [
    'CHECK (endezeit IS NULL OR endezeit > startzeit)',
  ];
}
