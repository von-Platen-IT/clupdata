import 'package:drift/drift.dart';

import 'rechnung_table.dart';
import 'waren_table.dart';

@DataClassName('RechnungPosition')
class RechnungPositionen extends Table {
  @override
  String get tableName => 'rechnung_position';

  IntColumn get id => integer().autoIncrement()();

  // Zugehörige Rechnung
  IntColumn get rechnungId =>
      integer().references(Rechnungen, #id, onDelete: KeyAction.cascade)();

  // Laufende Nummer (1, 2, 3...)
  IntColumn get positionNr => integer()();

  // Verkaufter Artikel (kann NULL sein wenn Ware gelöscht wurde)
  IntColumn get warenId => integer().nullable().references(
    Waren,
    #id,
    onDelete: KeyAction.setNull,
  )();

  // Artikelbezeichnung (Snapshot)
  TextColumn get bezeichnung => text().withLength(min: 1, max: 200)();

  // Menge
  RealColumn get menge => real()();

  // Preise pro Stück (Snapshot)
  RealColumn get einzelpreisNetto => real()();
  RealColumn get einzelpreisBrutto => real()();
  RealColumn get mwstSatz => real()();

  // Gesamtbeträge
  RealColumn get gesamtNetto => real()();
  RealColumn get gesamtBrutto => real()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {rechnungId, positionNr}, // Eine PositionNr pro Rechnung eindeutig
  ];
}
