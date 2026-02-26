import 'package:drift/drift.dart';
import 'bemerkung_table.dart';
import 'preis_table.dart';

/// Defines the structure for the `leistung` table.
/// Service or membership tier offered to members.
@DataClassName('LeistungItem')
class Leistung extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 200)();
  IntColumn get preisId => integer().references(Preis, #id, onDelete: KeyAction.restrict)();
  TextColumn get laufzeit => text()(); // enum: einmalig, monatlich, quartalsweise, jaehrlich
  IntColumn get bemerkungId => integer().nullable().references(Bemerkung, #id, onDelete: KeyAction.setNull)();
}
