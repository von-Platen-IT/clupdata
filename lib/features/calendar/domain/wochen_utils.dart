/// Hilfsfunktionen für Wochenberechnungen (Kursplan).
///
/// Alle Funktionen arbeiten mit Wochenanfängen (Montage).
library;

import '../../../core/utils/datum_utils.dart';

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
  return addiereTage(ohneZeit, -(ohneZeit.weekday - 1));
}

/// Liefert den Zeitraum einer Woche als (montag, sonntag).
({DateTime montag, DateTime sonntag}) wochenBereich(DateTime datum) {
  final montag = montagVon(datum);
  return (montag: montag, sonntag: addiereTage(montag, 6));
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

/// Liefert die ISO-8601-Kalenderwoche eines Datums (1–53).
///
/// Woche 1 ist die Woche, die den 4. Januar enthält.
int kalenderwoche(DateTime datum) {
  final donnerstag = _isoDonnerstag(datum);
  final ersterDonnerstag = _isoDonnerstag(DateTime(donnerstag.year, 1, 4));
  return 1 + differenzInTagen(ersterDonnerstag, donnerstag) ~/ 7;
}

/// Liefert den Montag der ISO-Woche, in die [datum] fällt (identisch zu
/// [montagVon], aber als klarer Einstiegspunkt für die Jahresansicht).
DateTime isoWocheMontag(DateTime datum) => montagVon(datum);

/// Liefert alle Montage der Kalenderwochen, die in den Monat [monat] fallen.
///
/// Eine Woche gilt als „im Monat", wenn mindestens einer ihrer Tage in den
/// Monat fällt. Ergebnis ist nach Datum sortiert.
List<DateTime> wochenImMonat(DateTime monat) {
  final erster = DateTime(monat.year, monat.month, 1);
  final letzter = DateTime(monat.year, monat.month + 1, 0);
  final ersteWoche = montagVon(erster);
  final wochen = <DateTime>[];
  var aktuell = ersteWoche;
  while (!aktuell.isAfter(letzter)) {
    wochen.add(aktuell);
    aktuell = addiereTage(aktuell, 7);
  }
  return wochen;
}

/// Liefert alle Tage eines Monats als Raster-Wochen (jeweils 7 Tage,
/// beginnend mit Montag). Der erste/letzte Monatstag wird mit Tagen der
/// Nachbarmonate aufgefüllt (vollständige Wochen).
List<List<DateTime>> monatsraster(DateTime monat) {
  final erster = DateTime(monat.year, monat.month, 1);
  final letzter = DateTime(monat.year, monat.month + 1, 0);
  final start = montagVon(erster);
  final wochen = <List<DateTime>>[];
  var aktuell = start;
  while (aktuell.isBefore(letzter) || _gleicherTag(aktuell, letzter)) {
    final woche = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      woche.add(addiereTage(aktuell, i));
    }
    wochen.add(woche);
    aktuell = addiereTage(aktuell, 7);
  }
  return wochen;
}

/// Liefert das Datum des [n]-ten Tages im Monat [monat] (1-basiert).
DateTime tagImMonat(DateTime monat, int n) =>
    DateTime(monat.year, monat.month, n);

/// True, wenn beide Datumsangaben denselben Kalendertag bezeichnen.
bool _gleicherTag(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Liefert den Donnerstag derselben ISO-Woche wie [datum].
DateTime _isoDonnerstag(DateTime datum) {
  final montag = montagVon(datum);
  return addiereTage(montag, 3);
}
