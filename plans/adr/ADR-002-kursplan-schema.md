# ADR-002: Kursplan-Schema mit zeitlich gültigen Plänen und DB-gesteuerten Kursfarben

> **Status**: Vorgeschlagen
> **Datum**: 2026-10-12
> **Betroffen**: `lib/core/database/tables/`, `lib/features/calendar/`
> **Kontext**: [`plans/kursplan.md`](../kursplan.md)

## Kontext

Der Kursplan ([`CalendarScreen`](../../lib/features/calendar/calendar_screen.dart:5)) ist
ein statischer Platzhalter; [`schedule_repository.dart`](../../lib/features/calendar/data/schedule_repository.dart:1)
enthält nur Legacy-Dummy-Klassen ohne Datenbankbezug. Benötigt wird ein Kursplan,
der zeigt, welche Kurse an welchen Wochentagen zu welchen Uhrzeiten stattfinden.
Kurse ändern sich über die Zeit – es müssen **mehrere Pläne mit Gültigkeitszeitraum**
(mindestens eine Woche) angelegt und **wochenweise navigiert** werden können.
Jeder Kurstyp ist **farblich eindeutig** gekennzeichnet.

## Entscheidung

1. **Drei neue Tabellen** (Schema v18, forward-only Migration):
   - [`kurs`](../../lib/core/database/tables/kurs_table.dart): Kurstyp mit
     `name`, `kampfsportart` und `farbe` (Hex `#RRGGBB`).
   - [`kursplan`](../../lib/core/database/tables/kursplan_table.dart): Plan mit
     `gueltig_von` (NOT NULL) und `gueltig_bis` (NULL = unbegrenzt).
   - [`kursplan_termin`](../../lib/core/database/tables/kursplan_termin_table.dart):
     wöchentlicher Termin (`wochentag` 1–7, `startzeit`/`endezeit` als `HH:mm`).

2. **Zeitbereichs-Gültigkeit auf Plan-Ebene**, nicht auf Termin-Ebene:
   Ein Plan bündelt alle Termine einer Saison/Phase. Wochen-Navigation ermittelt
   den gültigen Plan über `gueltig_von <= montag` (bzw. `gueltig_bis >= montag`).
   Bei Überschneidung gewinnt der Plan mit dem spätesten `gueltig_von`.

3. **Normalisierung auf Wochenanfänge**: `gueltig_von`/`gueltig_bis` werden beim
   Speichern auf den Montag normalisiert – die Gültigkeit ist immer ganzzahlig
   in Wochen (erfüllt „mindestens eine Woche").

4. **Farben in der DB** (`kurs.farbe` als Hex-String), nicht in Flutter-Code:
   Die Farbzuordnung ist Vereinsdaten und muss ohne App-Update änderbar sein.
   Die Statusfarben-Regel (Beitragsstatus) bleibt davon unberührt – Kursfarben
   sind eine separate, datengetriebene Kategorie.

5. **Zeitspeicherung als TEXT `HH:mm`**: Eindeutige, gut lesbare Anzeige;
   lexikographische Sortierung entspricht der zeitlichen Ordnung.

6. **FK-Regeln analog zum bestehenden Schema**:
   `kursplan_termin.kursplan_id` = CASCADE (wie `rechnung_position.rechnung_id`),
   `kursplan_termin.kurs_id` = RESTRICT (wie `beitrag.mitglied_id`).

## Alternativen

- **Termine direkt an `leistung` hängen**: `leistung` ist die Vertragsart der
  Abrechnung (Rhythmus/Preis) – Kurszeiten sind eine andere Domäne (Stundenplan).
  Vermischung würde beide Domänen belasten – abgelehnt.
- **Ein einzelner Plan ohne Gültigkeit**: Erfüllt nicht die Anforderung
  „Kurse ändern sich, mehrere Pläne" – abgelehnt.
- **Farben als eigene Tabelle `farbe`**: Over-Engineering für einen Hex-String –
  abgelehnt (KISS).
- **Zeiten als INTEGER (Minuten seit Mitternacht)**: Typsicherer für Berechnungen,
  aber schlechter lesbar in der DB/CSV; `HH:mm` reicht für die Anzeige-Logik –
  abgelehnt.

## Konsequenzen

- **Positiv**: Natürliche Modellierung von Saison-Plänen; Wochen-Navigation ist
  eine einfache Abfrage; Farben ohne Code-Änderung pflegbar; Schema folgt den
  bestehenden FK-/UUID-Konventionen.
- **Negativ / Aufwand**: Drei neue Tabellen + Migration v18; Verwaltungs-UI für
  Kurse und Pläne nötig; `kampfsportart` als Text ist bei Mehrfachnutzung
  normalisierungsbedürftig (bewusst aufgeschoben).
- **Neutral**: Route `/calendar` bleibt erhalten; Legacy-Code
  ([`schedule_repository.dart`](../../lib/features/calendar/data/schedule_repository.dart:1),
  [`calendar_screen.dart`](../../lib/features/calendar/calendar_screen.dart:5))
  wird entfernt.
