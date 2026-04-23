import 'package:drift/drift.dart';

import 'bemerkung_table.dart';
import 'mitglied_table.dart';

@DataClassName('Rechnung')
class Rechnungen extends Table {
  @override
  String get tableName => 'rechnung';

  IntColumn get id => integer().autoIncrement()();

  // Rechnungsnummer: R-YYYY-XXXXX
  TextColumn get rechnungsnummer =>
      text().withLength(min: 1, max: 100).unique()();

  // Optional: Mitglied (kann NULL sein für Walk-ins)
  IntColumn get mitgliedId => integer().nullable().references(
    Mitglieds,
    #id,
    onDelete: KeyAction.setNull,
  )();

  // Für nicht-Mitglieder (Walk-ins)
  TextColumn get kundeName => text().nullable().withLength(max: 200)();

  // Status: offen, bezahlt, storniert
  TextColumn get status => text()();

  // Termine
  DateTimeColumn get datum => dateTime()();
  DateTimeColumn get faelligAm => dateTime()();
  DateTimeColumn get bezahltAm => dateTime().nullable()();

  // Beträge
  RealColumn get betragNetto => real()();
  RealColumn get betragBrutto => real()();
  RealColumn get betragMwst => real()();

  // Optionale Bemerkung
  IntColumn get bemerkungId => integer().nullable().references(
    Bemerkung,
    #id,
    onDelete: KeyAction.setNull,
  )();

  // Zeitstempel
  DateTimeColumn get erstelltAm => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get aktualisiertAm =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (mitglied_id IS NOT NULL OR kunde_name IS NOT NULL)',
  ];
}
