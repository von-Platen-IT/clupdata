/// Hilfsfunktionen für Wochenberechnungen (Kursplan).
///
/// Alle Funktionen arbeiten mit Wochenanfängen (Montage).
library;

/// Deutsche Wochentags-Bezeichnungen (Index 0 = Montag, 1 = Dienstag, …).
const List<String> wochentagNamen = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

/// Liefert den Montag der Woche, in die [datum] fällt (ohne Uhrzeit).
DateTime montagVon(DateTime datum) {
  final ohneZeit = DateTime(datum.year, datum.month, datum.day);
  // DateTime.weekday: 1 = Montag … 7 = Sonntag
  return ohneZeit.subtract(Duration(days: ohneZeit.weekday - 1));
}

/// Liefert den Zeitraum einer Woche als (montag, sonntag).
({DateTime montag, DateTime sonntag}) wochenBereich(DateTime datum) {
  final montag = montagVon(datum);
  return (montag: montag, sonntag: montag.add(const Duration(days: 6)));
}

/// Formatiert eine Woche als deutschen Bereich, z. B. „05.10. – 11.10.2026".
String formatiereWochenBereich(DateTime datum) {
  final bereich = wochenBereich(datum);
  final f = _zweiStellen;
  final m = bereich.montag;
  final s = bereich.sonntag;
  return '${f(m.day)}.${f(m.month)}. – ${f(s.day)}.${f(s.month)}.${s.year}';
}

/// Formatiert Minuten seit Mitternacht als `HH:mm`.
String formatiereZeit(int minuten) {
  final f = _zweiStellen;
  return '${f(minuten ~/ 60)}:${f(minuten % 60)}';
}

/// Parst eine Zeit im Format `HH:mm` in Minuten seit Mitternacht.
///
/// Liefert `null` bei ungültigem Format oder Wertebereich.
int? parseZeit(String text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final stunde = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (stunde > 23 || minute > 59) return null;
  return stunde * 60 + minute;
}

String _zweiStellen(int wert) => wert.toString().padLeft(2, '0');
