import 'package:drift/drift.dart';
import '../../utils/uuid_helper.dart';

import 'rechnung_table.dart';

/// Unveränderliche Status-History für Waren-Rechnungen, analog
/// [`beitrag_status_verlauf_table.dart`](beitrag_status_verlauf_table.dart).
///
/// Jede Statusänderung erzeugt einen neuen Eintrag. Die `bemerkung` ist
/// Pflicht und macht jede Statusänderung nachvollziehbar.
@DataClassName('RechnungStatusVerlauf')
@TableIndex(
  name: 'idx_rechnung_status_verlauf_rechnung',
  columns: {#rechnungId},
)
@TableIndex(name: 'idx_rechnung_status_verlauf_uuid', columns: {#uuid}, unique: true)
class RechnungStatusVerlaeufe extends Table {
  @override
  String get tableName => 'rechnung_status_verlauf';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid =>
      text().unique().nullable().clientDefault(() => generateUuid())();

  IntColumn get rechnungId =>
      integer().references(Rechnungen, #id, onDelete: KeyAction.cascade)();

  /// Neuer Status: entwurf, offen, teilbezahlt, bezahlt, angemahnt, storniert.
  TextColumn get status => text()();

  /// Exakter Zeitstempel der Statusänderung.
  DateTimeColumn get geaendertAm => dateTime()();

  /// PFLICHTFELD: Erklärung/Grund für die Statusänderung.
  TextColumn get bemerkung => text().withLength(min: 1, max: 500)();
}
