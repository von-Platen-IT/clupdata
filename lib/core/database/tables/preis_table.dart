import 'package:drift/drift.dart';
import 'bemerkung_table.dart';

/// Defines the structure for the `preis` table.
/// Price entity. Nettopreis is always computed at runtime from bruttopreis.
@DataClassName('PreisItem')
class Preis extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get bruttopreis => real()();
  IntColumn get bemerkungId => integer().nullable().references(Bemerkung, #id, onDelete: KeyAction.setNull)();
}
