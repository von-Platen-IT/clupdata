# ADR-006: Mahnwesen als 3-Stufen-Prozess mit konfigurierbaren Fristen

> **Status**: Angenommen
> **Datum**: 2026-10-14
> **Kontext**: [`plans/rechnungsstellung-redesign.md`](../rechnungsstellung-redesign.md:1), [`ADR-004`](ADR-004-billing-datenmodell.md:1)

## Kontext

Überfällige Zahlungen werden heute nur über den manuellen Status `angemahnt` (Beiträge) bzw. gar nicht (Rechnungen) gekennzeichnet. Es gibt keine Fristenlogik, keine Mahnstufen, keine Gebühren und keinen strukturierten Ablauf. Rechercheergebnis (siehe [`plans/rechnungsstellung-redesign.md`](../rechnungsstellung-redesign.md:113) Kap. 3.2): Der Branchenstandard ist ein **3-Stufen-Mahnverfahren** mit Zahlungserinnerung → 1. Mahnung → 2. Mahnung → Inkasso, Fristen typischerweise 7/14/21 Tage nach Fälligkeit, Mahngebühren stufenweise, Verzugszinsen gem. § 288 BGB bei Eskalation.

## Entscheidung

1. **Mahnstufen-Modell** in neuer Tabelle [`mahnung`](../rechnungsstellung-redesign.md:273):
   - Stufe 1 = Zahlungserinnerung (keine Gebühr), Stufe 2 = 1. Mahnung, Stufe 3 = 2. Mahnung, Stufe 4 = Inkasso/Eskalation
2. **Fristen & Gebühren konfigurierbar** über [`stammdaten`](../rechnungsstellung-redesign.md:313) (Default: 7/14/21 Tage, Gebühren 0/2,00/5,00 €)
3. **Mahnlauf-Wizard** (3 Schritte): Überfällige auswählen (mit automatischem Stufen-Vorschlag) → Vorschau der Mahnschreiben → Erstellen. Erstellen bucht [`mahnung`](../rechnungsstellung-redesign.md:273)-Einträge, setzt Status `angemahnt` (inkl. [`rechnung_status_verlauf`](../rechnungsstellung-redesign.md:257)) und erzeugt PDF-Mahnvorlagen.
4. **Nur fällige Belege**: Auslöser ist `faellig_am` + Toleranz ([`faelligkeit_service.dart`](../rechnungsstellung-redesign.md:331)) – Mahnungen vor Fälligkeit sind ausgeschlossen.
5. **Eskalation zu `inkasso`** bleibt manuell (bewusste Entscheidung des Vorstands), wird aber durch die Vorschlagslogik angeboten.

## Konsequenzen

- **Positiv**: Strukturierter, nachvollziehbarer Mahnprozess; jedes Mahnschreiben ist dokumentiert ([`mahnung`](../rechnungsstellung-redesign.md:273) als Historie).
- **Positiv**: Fristen/Gebühren sind Stammdaten – Anpassungen ohne Code-Änderung.
- **Positiv**: Identische Logik für Beiträge und Waren-Rechnungen (über [`zahlung`](../rechnungsstellung-redesign.md:241)/[`mahnung`](../rechnungsstellung-redesign.md:273)-Bezug).
- **Negativ**: PDF-Mahnvorlagen sind zusätzlicher Aufwand (Phase 5).
- **Negativ**: Automatischer Versand (E-Mail) ist nicht Teil dieses ADRs – Mahnschreiben werden erzeugt und manuell versendet (Desktop-App, kein Mail-Server).

## Alternativen verworfen

- **Nur manueller Status `angemahnt`** (Status quo): Kein strukturierter Prozess, keine Nachvollziehbarkeit.
- **Vollautomatischer Dunning-Lauf (SaaS-Muster)**: Passt nicht zu einer Desktop-App ohne Versandinfrastruktur; der Wizard mit Vorschau ist der richtige Grad der Automatisierung.
