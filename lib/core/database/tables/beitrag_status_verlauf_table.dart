import 'package:drift/drift.dart';
import 'beitraege_table.dart';

/// Status history for a [Beitraege] record.
/// Every status change creates an immutable entry in this table.
/// Deleting a Beitrag cascades and removes all its history entries.
class BeitragStatusVerlauf extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Reference to the parent [Beitraege] record.
  /// ON DELETE CASCADE — history is removed when the Beitrag is deleted.
  IntColumn get beitragId =>
      integer().references(Beitraege, #id, onDelete: KeyAction.cascade)();

  /// The new status value at the time of this change.
  /// Enum: [kontiert, offen, bezahlt, angemahnt, storniert, inkasso]
  TextColumn get status => text().withLength(max: 20)();

  /// Exact timestamp when this status was set.
  DateTimeColumn get geaendertAm => dateTime()();

  /// Required free-text note explaining why the status was changed.
  /// Must not be empty - ensures every status change is traceable.
  TextColumn get bemerkung => text().withLength(min: 1, max: 500)();
}
