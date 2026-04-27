import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';
import 'bemerkung_table.dart';

/// Defines the structure for the `preis` table.
/// Price entity. Nettopreis is always computed at runtime from bruttopreis.
@DataClassName('PreisItem')
@TableIndex(name: 'idx_preis_uuid', columns: {#uuid}, unique: true)
class Preis extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();
  RealColumn get bruttopreis => real()();
  IntColumn get bemerkungId => integer().nullable().references(
    Bemerkung,
    #id,
    onDelete: KeyAction.setNull,
  )();
}
