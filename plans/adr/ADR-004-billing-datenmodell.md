# ADR-004: Einheitliches Billing-Datenmodell (Zahlungen, Status-Historie, Fälligkeit)

> **Status**: Angenommen
> **Datum**: 2026-10-14
> **Kontext**: [`plans/rechnungsstellung-redesign.md`](../rechnungsstellung-redesign.md:1)
> **Betrifft**: Schema-Version 18 → 19

## Kontext

Beiträge ([`beitrag`](../../lib/assets/data/structur.md:207)) und Waren-Rechnungen ([`rechnung`](../../lib/assets/data/structur.md:247)) sind getrennte Belegarten mit eigenen Nummernkreisen ([`RE-`/`R-`](../../lib/assets/data/structur.md:915)). Beide haben bislang **kein Zahlungsmodell**: Ein Statuswechsel auf `bezahlt` dokumentiert weder Betrag noch Zahlungsart. Teilzahlungen sind unmöglich, offene Posten nur indirekt über den Status ableitbar. Beiträge kennen kein Fälligkeitsdatum, Rechnungen haben keinen Status-Verlauf (nur Beiträge via [`beitrag_status_verlauf`](../../lib/assets/data/structur.md:57)).

## Entscheidung

Wir führen ein **gemeinsames Zahlungsmodell** über beide Belegarten ein:

1. **Neue Tabelle [`zahlung`](../../lib/assets/data/structur.md:247)** – Zahlungseingänge (auch Teilzahlungen, negative Beträge als Gutschrift-Ausgleich) mit Bezug zu genau einem Beleg (`beitrag_id` XOR `rechnung_id`).
2. **Neue Tabelle [`rechnung_status_verlauf`](../../lib/assets/data/structur.md:57)** – analog [`beitrag_status_verlauf`](../../lib/assets/data/structur.md:57), Bemerkung ist Pflicht.
3. **`beitrag.faellig_am`** (NOT NULL, Default `kontiert_am + 14 Tage`) als Grundlage des Mahnwesens.
4. **Status-Enums erweitert**: Beiträge `+ teilbezahlt`, Rechnungen `+ entwurf, teilbezahlt, angemahnt`.
5. **Saldo-Prinzip**: Der Status wird aus `SUM(zahlungen)` vs. Forderung abgeleitet (Vollzahlung → `bezahlt`, Teilzahlung → `teilbezahlt`). Der Status wird bei jeder Zahlungsbuchung automatisch aktualisiert.

Detaillierte Felddefinitionen: [`plans/rechnungsstellung-redesign.md`](../rechnungsstellung-redesign.md:241) Kapitel 5.

## Konsequenzen

- **Positiv**: Teilzahlungen, Zahlungsabgleich (camt), offene Posten und Mahnwesen werden möglich; beide Belegarten nutzen dieselbe Zahlungslogik ([`ZahlungService`](../rechnungsstellung-redesign.md:331)).
- **Positiv**: Migration ist rein additiv (neue Tabellen + eine Spalte + Enum-Erweiterungen) – forward-only, keine Datenverluste.
- **Negativ**: Zwei Tabellen mehr im Schema; jede Statusänderung braucht künftig einen Verlaufseintrag (bewusst: Nachvollziehbarkeit/GoBD).
- **Negativ**: Status-Duplizität (`status` + `status_datum` in [`beitrag`](../../lib/assets/data/structur.md:221)) bleibt erhalten – bewusst, um bestehende Auswertungen nicht zu brechen.

## Alternativen verworfen

- **Nur Status ohne Zahlungstabelle**: Zu wenig für Teilzahlungen und Zahlungsabgleich.
- **Vereinheitlichung beider Belegarten in einer Tabelle**: Bricht Nummernkreise, bestehende Auswertungen und die 1-Leistung-vs.-N-Positionen-Unterscheidung – unnötig großes Risiko.
