# ADR-005: Rechnungszentrale als einheitliches UI-Konzept (Drei-Säulen-Design)

> **Status**: Angenommen
> **Datum**: 2026-10-14
> **Kontext**: [`plans/rechnungsstellung-redesign.md`](../rechnungsstellung-redesign.md:1)

## Kontext

Die Rechnungsstellung ist heute fragmentiert:

- **Beiträge**: 5-Schritt-Wizard ([`RechnungslegungWizard`](../../lib/features/rechnungserstellung/presentation/rechnungslegung_wizard.dart:1)) mit Modus-Eigenem Schritt – für den Standardfall „Monat abrechnen" zu viele Klicks
- **Waren**: 743-Zeilen-Monolith-Dialog ([`NeueRechnungDialog`](../../lib/features/rechnungen/widgets/neue_rechnung_dialog.dart:40)) mit hart kodierter MwSt 19 %
- **POS**: reiner Placeholder ([`PosScreen`](../../lib/features/pos/pos_screen.dart:8)) mit nicht implementiertem Stub ([`SalesRepository`](../../lib/features/pos/data/sales_repository.dart:19))

Nutzer müssen zwischen drei unterschiedlichen Bedienmodellen wechseln, Zahlungseingang und Mahnwesen existieren nicht als eigene Workflows.

## Entscheidung

Wir bauen eine **Rechnungszentrale mit drei Säulen** auf – eine gemeinsame Domäne [`lib/features/billing/`](../rechnungsstellung-redesign.md:279) mit konsistenten Bedienmustern:

1. **Beiträge** – 4-Schritt-Abrechnungslauf ([`plans/rechnungsstellung-redesign.md`](../rechnungsstellung-redesign.md:99) Kap. 4.1): Empfängerkreis als Chip-Leiste + Zeitraum in **einem** Schritt, editierbare Vorschau, Freigabe mit Zahlungsziel, Ergebnis mit Anschlussaktionen. **2-Klick-Standardfall** (Monat abrechnen).
2. **Verkauf & Rechnungen** – echte POS-Kasse (Warenkorb, Mitglied/Walk-in, Zahlart Bar/Karte/Rechnung, Tagesabschluss) + aufgeteilter Rechnungs-Editor ([`RechnungEditorDialog`](../../lib/features/rechnungen/widgets/neue_rechnung_dialog.dart:40) + [`PositionEditor`](../../lib/features/rechnungen/widgets/neue_rechnung_dialog.dart:17)) + Sammelrechnung + Gutschrift.
3. **Zahlungen & Mahnungen** – gemeinsame Offene-Posten-Liste über beide Belegarten, Zahlungsdialog mit Teilzahlungen, Mahnlauf-Wizard (3 Stufen).

**Gestaltungsprinzipien** (verbindlich, siehe Kapitel 6.2 des Hauptplans):
- Editierbare Vorschau vor jedem Datenbank-Commit
- Saldo & Fälligkeit in jeder Liste sichtbar
- Kontextsensitive Zeilenaktionen statt globaler Menüs
- Statusfarben zentral ([`beitrag_status_colors.dart`](../../lib/features/beitraege/utils/beitrag_status_colors.dart:1), [`rechnung_status_colors.dart`](../../lib/features/rechnungen/utils/rechnung_status_colors.dart:1))

## Konsequenzen

- **Positiv**: Ein konsistentes Bedienmodell über alle Rechnungsvorgänge; der Standardfall ist mit ≤ 2 Klicks erledigt.
- **Positiv**: Gemeinsame Services ([`zahlung_service.dart`](../rechnungsstellung-redesign.md:331), [`faelligkeit_service.dart`](../rechnungsstellung-redesign.md:331)) vermeiden doppelte Logik.
- **Negativ**: Das Feature [`lib/features/rechnungserstellung/`](../../lib/features/rechnungserstellung/services/abrechnung_service.dart:1) wird komplett ersetzt (Periodenlogik wird migriert, nicht neu geschrieben).
- **Negativ**: Höherer Implementierungsaufwand in Phase 3–4; Entwurf des Wizards ist aufwändiger als ein einzelner Dialog.

## Alternativen verworfen

- **Bestehende Dialoge einzeln verbessern**: Löst die Fragmentierung nicht; zwei Bedienwelten bleiben.
- **Ein einziger „Rechnungs"-Screen für alles**: Überlädt den Screen; Beitrags-Abrechnung und Kassenvorgang sind zu unterschiedlich.
