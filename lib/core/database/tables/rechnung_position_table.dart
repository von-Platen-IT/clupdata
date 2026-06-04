import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';

import 'rechnung_table.dart';
import 'waren_table.dart';

@DataClassName('RechnungPosition')
@TableIndex(name: 'idx_rechnung_pos_rechnung', columns: {#rechnungId})
@TableIndex(name: 'idx_rechnung_pos_waren', columns: {#warenId})
@TableIndex(name: 'idx_rechnung_position_uuid', columns: {#uuid}, unique: true)
class RechnungPositionen extends Table {
  @override
  String get tableName => 'rechnung_position';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();

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
  RealColumn get menge => real().withDefault(const Constant(1.0))();

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
