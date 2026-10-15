/// DST-sichere Datumsarithmetik (Kalendertage).
///
/// Alle Funktionen arbeiten mit Kalendertagen und sind unabhängig von der
/// Sommerzeit-Umstellung (25-/23-Stunden-Tage). Sie ersetzen die fehleranfällige
/// Verwendung von `DateTime.add(Duration(days: n))` bzw.
/// `DateTime.difference(...).inDays`, die über die Zeitumstellung um einen Tag
/// kippen können.
library;

/// Addiert [tage] Kalendertage DST-sicher (ohne Uhrzeit-Verschiebung).
///
/// Verwendet die Kalender-Konstruktion `DateTime(y, m, d + tage)` statt
/// `add(Duration(days: tage))`. Letzteres addiert exakt 24 h pro Tag und
/// verschiebt das Datum bei der Sommerzeit-Umstellung (25-Stunden-Tag) um
/// einen Tag – z. B. `19.10.2026 + 7 Tage` → `25.10.2026 23:00` statt
/// `26.10.2026 00:00`. Die Uhrzeit von [datum] bleibt erhalten.
DateTime addiereTage(DateTime datum, int tage) {
  final ziel = DateTime(datum.year, datum.month, datum.day + tage);
  return DateTime(
    ziel.year,
    ziel.month,
    ziel.day,
    datum.hour,
    datum.minute,
    datum.second,
    datum.millisecond,
    datum.microsecond,
  );
}

/// Liefert die Anzahl ganzer Kalendertage von [von] bis [bis] (DST-sicher).
///
/// Positiv, wenn [bis] nach [von] liegt. Die Uhrzeit wird ignoriert.
int differenzInTagen(DateTime von, DateTime bis) {
  final a = DateTime.utc(von.year, von.month, von.day);
  final b = DateTime.utc(bis.year, bis.month, bis.day);
  return b.difference(a).inDays;
}
