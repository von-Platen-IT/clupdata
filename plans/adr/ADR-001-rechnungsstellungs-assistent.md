# ADR-001: Einheitlicher Rechnungsstellungs-Assistent mit vier Abrechnungsmodi

> **Status**: Vorgeschlagen
> **Datum**: 2026-10-12
> **Betroffen**: `lib/features/rechnungserstellung/`, `lib/features/beitraege/`
> **Kontext**: [`plans/rechnungsstellung-konzept.md`](../rechnungsstellung-konzept.md)

## Kontext

Die Rechnungsstellung für Beiträge existiert doppelt: der alte
[`RechnungslegungDialog`](../../lib/features/beitraege/presentation/dialogs/rechnungslegung_dialog.dart:14)
neben dem neueren
[`BeitraegeBatchDialog`](../../lib/features/rechnungserstellung/presentation/dialogs/beitraege_batch_dialog.dart:20).
Beide duplizieren Kernlogik (Duplikat-Prüfung, Preis-Snapshot, Status-Verlauf) und
können nur „alle Mitglieder für einen Monat" abrechnen. Die Bedienung weicht stark
von etablierter Rechnungssoftware ab (keine Vorschau, keine Einzel-/Mehrfachauswahl,
keine kursbezogene Abrechnung). Ziel ist die Angleichung an bewährte
Rechnungsstellungs-UX mit den vier Moden: Zeitperioden, einzelnes Mitglied,
ausgewählte Mitglieder, Kurse.

## Entscheidung

1. **Ein Wizard statt zweier Dialoge**: Ein `RechnungslegungWizard`
   (5 Schritte: Modus → Auswahl → Zeitraum & Optionen → Vorschau → Ergebnis)
   ersetzt beide Dialoge. Alle Einstiegspunkte (Menü, Shortcut, Beiträge-Action)
   öffnen denselben Wizard.

2. **Vorschau vor Commit**: Vor der Erstellung zeigt eine editierbare Tabelle alle
   betroffenen Beiträge inkl. bereits abgerechneter Perioden (Idempotenz sichtbar).
   Erst die bestätigte Auswahl wird geschrieben.

3. **Vier Abrechnungsmodi** als `AbrechnungsModus`-Enum:
   `zeitperioden`, `einzelnesMitglied`, `ausgewaehlteMitglieder`, `kurse`.

4. **„Kurse" = `leistung`**: Ohne Schema-Änderung entspricht ein Kurs einem
   [`leistung`-Datensatz](../../lib/core/database/tables/leistung_table.dart:12)
   (Vertragsart mit Rhythmus `laufzeit`). Eine eigenständige `kurs`-Tabelle wird
   erst beim Ausbau des Kursplans ([`CalendarScreen`](../../lib/features/calendar/calendar_screen.dart:5))
   in Betracht gezogen (separates ADR).

5. **Rhythmus aus Vertrag**: Die Periodenbildung richtet sich nach
   [`leistung.laufzeit`](../../lib/core/database/tables/leistung_table.dart:19)
   (monatlich → 1 Beitrag/Monat, quartalsweise → 1 Beitrag/Quartal, jaehrlich → 1/Jahr,
   einmalig → nur einmal).

6. **Ein vereinheitlichter [`AbrechnungService`](../../lib/features/rechnungserstellung/services/abrechnung_service.dart)**
   ersetzt [`RechnungslegungService`](../../lib/features/beitraege/services/rechnungslegung_service.dart:29),
   [`BeitraegeBatchService`](../../lib/features/rechnungserstellung/services/beitraege_batch_service.dart:36)
   und die Basisklasse [`BatchRechnungService`](../../lib/features/rechnungserstellung/services/batch_rechnung_service.dart:15)
   (Komposition statt Vererbung).

7. **Atomare Batch-Erstellung**: Die gesamte Erstellung läuft in einer
   `db.transaction(...)`; bei Fehlern vollständiger Rollback.

## Alternativen

- **Alt-Dialog erweitern**: Verwirft die Vorschau-Architektur und perpetuiert die
  doppelte Logik — abgelehnt.
- **Feature-Entwurf „Rechnungslauf" als eigener Screen**: Mehr Platz, bricht aber
  die dialogbasierte Bedienung der App und den bestehenden Menüeinstieg — abgelehnt
  (Wizard-Dialog bleibt im gewohnten Muster von
  [`AppEditDialogScaffold`](../../lib/common_widgets/app_edit_dialog_scaffold.dart:1)).
- **Eigene `kurs`-Tabelle**: Nicht nötig, solange `leistung` die Kursrolle trägt;
  würde Schema v18 + Migration erfordern — aufgeschoben.

## Konsequenzen

- **Positiv**: Eine Codebasis für Rechnungslegung; benutzerfreundliche, an
  Rechnungssoftware angelehnte Bedienung; atomare Batch-Erstellung; die vier
  geforderten Modi sind abgedeckt.
- **Negativ / Aufwand**: Alte Dialoge und Services werden gelöscht
  (Breaking Change intern, aber ohne DB-Migration); Nutzer müssen sich an den
  Wizard gewöhnen; Testaufwand für Service- und Widget-Tests.
- **Neutral**: [`BatchRechnungResult`](../../lib/features/rechnungserstellung/domain/models/batch_rechnung_result.dart:5)
  bleibt als einziges Result-Modell; `RechnungslegungResult` entfällt.
- **Datenintegrität**: Keine Schema-Änderung im MVP; optionale Phase 2
  (`faellig_am`, `zahlungsziel_tage`) erfordert eigenes ADR + Migration v18
  (forward-only) und vorherige Aktualisierung der SSOT
  [`structur.md`](../../lib/assets/data/structur.md:1).
