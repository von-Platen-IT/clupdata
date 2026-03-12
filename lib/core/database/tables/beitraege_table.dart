import 'package:drift/drift.dart';

import 'bemerkung_table.dart';
import 'leistung_table.dart';
import 'mitglied_table.dart';
import 'preis_table.dart';

@DataClassName('Beitrag')
class Beitraege extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mitgliedId =>
      integer().references(Mitglieds, #id, onDelete: KeyAction.restrict)();
  IntColumn get leistungId =>
      integer().references(Leistung, #id, onDelete: KeyAction.restrict)();
  IntColumn get preisId =>
      integer().nullable().references(Preis, #id, onDelete: KeyAction.setNull)();
  
  TextColumn get rechnungsnummer =>
      text().withLength(min: 1, max: 100).unique()();
  
  // Status: kontiert, offen, bezahlt, angemahnt, storniert, inkasso
  TextColumn get status => text()();
  
  DateTimeColumn get kontiertAm => dateTime()();
  DateTimeColumn get statusDatum => dateTime()();
  
  IntColumn get bemerkungId =>
      integer().nullable().references(Bemerkung, #id, onDelete: KeyAction.setNull)();
}
