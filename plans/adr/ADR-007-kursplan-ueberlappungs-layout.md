# ADR-007: Überlappungs-Layout im Kursplan (Lane-Packing + responsiver Block)

> **Status**: Vorgeschlagen
> **Datum**: 2026-10-15
> **Betroffen**: `lib/features/calendar/presentation/widgets/`, `lib/features/calendar/domain/`
> **Kontext**: [`plans/kursplan-ueberlappung.md`](../kursplan-ueberlappung.md), [`ADR-002`](ADR-002-kursplan-schema.md)

## Kontext

Die Wochenansicht des Kursplans ([`KursplanWochenGrid`](../../lib/features/calendar/presentation/widgets/kursplan_wochen_grid.dart:17))
stellt Kurstermine als farbige Blöcke in einem Zeit-Raster dar. Finden **zwei Kurse
gleichzeitig** statt, teilen sich die Blöcke die Spaltenbreite. Dabei tritt ein
**RenderFlex-Overflow** auf: Der Blockinhalt ([`_KursBlock`](../../lib/features/calendar/presentation/widgets/kursplan_wochen_grid.dart:217))
rendert stets zwei Textzeilen in einer festen Blockhöhe; die halbierte Breite erzwingt
zusätzlich einen Namensumbruch auf zwei Zeilen, sodass der benötigte vertikale Platz
(~38 px) die verfügbare Höhe (22 px bei einem 30-Min-Slot) überschreitet.

Zusätzlich ist die bestehende Gruppierung ([`_ueberlappungsGruppen()`](../../lib/features/calendar/presentation/widgets/kursplan_wochen_grid.dart:195))
zu grob: Sie fasst **transitiv** überlappende Termine zu einer Gruppe zusammen und teilt
die Breite gleichmäßig auf, auch wenn sich nicht alle Mitglieder gegenseitig überlappen.
Das verschwendet Breite und verschärft den Overflow.

## Entscheidung

1. **Greedy-Lane-Packing (Intervall-Partitionierung)** ersetzt die naive Gruppierung.
   Jeder Termin wird der ersten Spur zugewiesen, deren letzter Termin vor seiner
   Startzeit endet; andernfalls wird eine neue Spur angelegt. Die Blockbreite ergibt
   sich aus der **maximalen Parallelität** des Tages, nicht aus der Gruppengröße.
   → Maximale Breite, minimaler Overflow.

2. **Responsiver Block-Inhalt** über `LayoutBuilder`: Der Block rendert Name und Zeit
   nur, wenn Höhe und Breite ausreichen; bei zu wenig Platz wird auf eine Zeile bzw.
   reine Farbfläche reduziert. Ein `ClipRect` dient als Sicherheitsnetz gegen Overflow.

3. **Parallel-Indikator + Tooltip**: Gleichzeitig laufende Termine erhalten ein
   Parallel-Symbol; ein Tooltip listet die parallel laufenden Kurse auf.

4. **Zeitachsen-Clamping**: `startSlot`/`endSlot` werden auf `[0, slotAnzahl]` begrenzt;
   Termine außerhalb des Anzeigefensters (06:00–22:00) werden am Rand angedockt.

5. **Reine, testbare Layout-Funktionen** werden aus dem Widget herausgezogen
   (`lib/features/calendar/domain/kursplan_layout.dart`), damit die Algorithmik ohne
   Widget-Test abgesichert werden kann.

## Alternativen

- **Nur Overflow beheben (Text kürzen), Gruppierung beibehalten**: Behebt den Fehler,
  lässt aber unnötig schmale Blöcke bestehen – abgelehnt (Ursache 2.2 bleibt).
- **Überlappende Blöcke übereinanderstapeln (Overlay mit Offset, „+n"-Badge)**:
  Google-Kalender-Stil; platzsparend, aber schlechter lesbar und aufwendiger in der
  Interaktion – als spätere Option vorgemerkt, nicht jetzt.
- **Horizontales Scrollen je Tagesspalte**: Löst Breitenknappheit, verschlechtert aber
  die Wochenübersicht – abgelehnt.
- **Termine außerhalb 06:00–22:00 ausblenden**: Informationsverlust – abgelehnt
  (stattdessen Clamping + Tooltip-Hinweis).

## Konsequenzen

- **Positiv**: Overflow-Fehler bei gleichzeitigen Kursen behoben; korrekte, breiten-
  optimierte Darstellung; Parallelität sichtbar; Layout-Logik unit-testbar; keine
  Schema-/Migrationsänderung.
- **Negativ / Aufwand**: Umbau von `_TagSpalte`/`_KursBlock`; neue Domain-Datei;
  zusätzliche Tests; Tagesansicht muss angeglichen werden.
- **Neutral**: Öffentliche Widget-Signatur (`KursplanWochenGrid`) bleibt unverändert;
  Route `/calendar` und Datenmodell bleiben unberührt.
