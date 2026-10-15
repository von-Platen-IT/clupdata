# ADR-008: Scroll-Verantwortung in den Kursplan-Ansichten

> **Status**: Vorgeschlagen
> **Datum**: 2026-10-15
> **Betroffen**: `lib/features/calendar/presentation/`
> **Kontext**: [`plans/kursplan-tagesansicht-layout-fix.md`](../kursplan-tagesansicht-layout-fix.md), [`ADR-007`](ADR-007-kursplan-ueberlappungs-layout.md)

## Kontext

Die Kursplan-Ansichten (Jahr/Monat/Woche/Tag) werden im
[`_AnsichtsBereich`](../../lib/features/calendar/presentation/kursplan_screen.dart:218)
innerhalb eines [`Expanded`](../../lib/features/calendar/presentation/kursplan_screen.dart:55)
gerendert und erhalten damit eine **begrenzte** Höhe.

Für die **Tagesansicht** wurde zusätzlich ein äußerer
[`SingleChildScrollView`](../../lib/features/calendar/presentation/kursplan_screen.dart:275)
verwendet. Da die Tagesansicht intern ein
[`Expanded`](../../lib/features/calendar/presentation/widgets/kursplan_tagesansicht.dart:50)
enthält, kollidiert die unbegrenzte Höhe des ScrollViews mit dem Flex-Kind:

```
RenderFlex children have non-zero flex but incoming height constraints are unbounded.
```

Zusätzlich brachte die Tagesansicht bereits einen **eigenen** Scroll-Viewport
mit ([`SingleChildScrollView`](../../lib/features/calendar/presentation/widgets/kursplan_tagesansicht.dart:51)),
sodass zwei verschachtelte Scroll-Viewports entstanden.

## Entscheidung

1. **Ein Widget, ein Scroll-Viewport.** Jede Kursplan-Ansicht ist selbst für
   ihr Scrollen verantwortlich, wenn ihr Inhalt die verfügbare Höhe
   überschreiten kann.
2. **Der Screen wickelt Ansichten nicht in einen zusätzlichen
   `SingleChildScrollView`**, wenn die Ansicht bereits intern scrollt oder ein
   `Expanded`/`Flexible` verwendet.
3. **Konkret**: Der äußere `SingleChildScrollView` im `case KursplanAnsicht.tag`
   wird entfernt. Die Tagesansicht nutzt die begrenzte Höhe aus dem `Expanded`
   des Screens und scrollt über ihren internen Viewport.
4. **Wochenansicht bleibt unverändert**: Das
   [`KursplanWochenGrid`](../../lib/features/calendar/presentation/widgets/kursplan_wochen_grid.dart:1)
   hat eine feste Höhe und **kein** `Expanded`; der äußere ScrollView ist dort
   korrekt und notwendig.
5. **Initialer Scroll-Offset gehört zum Widget.** Die Tagesansicht bestimmt
   ihren Startausschnitt selbst (initial **15:00 Uhr** oben, da Kurse
   überwiegend abends stattfinden) über einen `useScrollController`
   (flutter_hooks) – nicht der Screen. Der Zeitstrahl bleibt 06:00–22:00.

## Alternativen

- **Tagesansicht defensiv umbauen** (`mainAxisSize: MainAxisSize.min` +
  `Flexible` statt `Expanded`): Behebt die Assertion, lässt aber das doppelte
  Scrollen bestehen und verhindert eine Anpassung an die Fensterhöhe – abgelehnt.
- **`IntrinsicHeight` um die Column**: Teuer im Layout und behebt die Ursache
  nicht – abgelehnt.
- **Feste Höhe für die Tagesansicht im Screen**: Dupliziert Layoutwissen und
  bricht bei Fenster-Resize – abgelehnt.

## Konsequenzen

- **Positiv**: RenderFlex-Fehler behoben; kein doppeltes Scrollen; klare
  Verantwortlichkeit; Wochenansicht unberührt; Kurse abends ohne Scrollen
  sichtbar; keine Schema-/Migrationsänderung.
- **Negativ / Aufwand**: minimal (eine Zeile im Screen, `HookWidget`-Umbau der
  Tagesansicht); Regel muss bei neuen Ansichten beachtet werden.
- **Neutral**: Öffentliche Widget-Signaturen, Route `/calendar` und Datenmodell
  bleiben unverändert.
