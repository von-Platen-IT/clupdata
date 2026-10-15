# Korrekturplan: Logikfehler im Billing-/Abrechnungs-Bereich

> Erstellt: 2026-10-15 | Mode: Flutter Architect | Schema-Änderung: **keine** (SSOT `structur.md` bleibt unberührt)

## 1. Analyse-Umfang

Geprüft: `features/billing/**`, `features/abrechnung/data/abrechnung_service.dart`,
`core/data/rechnungsnummer_generator.dart`, `core/utils/datum_utils.dart`.

## 2. Gefundene Fehler

| # | Schwere | Datei | Problem |
|---|---------|-------|---------|
| F1 | **Kritisch** | [`offene_posten_repository.dart`](../lib/features/billing/data/offene_posten_repository.dart) | `selectOnly(beitraege).join(zahlungen)` selektiert nur `SUM(betrag)`, kein `GROUP BY`. `row.readTable(db.beitraege)` schlägt fehl bzw. es kommt nur eine aggregierte Zeile → Offene-Posten-Liste und Mahnvorschläge defekt. Zusätzlich N+1-Query (`_ladeBeitragsForderung` je Beitrag). |
| F2 | Hoch | [`mahnung_service.dart`](../lib/features/billing/services/mahnung_service.dart) | `erstelleMahnlauf`: `try/catch` innerhalb *einer* Transaktion ohne Savepoint → bei Fehler bleibt die Mahnung ohne Statuswechsel stehen (Inkonsistenz). |
| F3 | Hoch | [`mahnung_service.dart`](../lib/features/billing/services/mahnung_service.dart) | Stufe 4 (Inkasso) wird sofort nach Stufe 3 vorgeschlagen (Frist = `stufe3FristTage`, bereits erfüllt) und setzt Status `angemahnt` statt `inkasso`. Stufe-Fristen werden zudem nicht relativ zur letzten Mahnung geprüft. |
| F4 | Mittel | [`offener_posten.dart`](../lib/features/billing/domain/models/offener_posten.dart) | `tageUeberfaellig` nutzt `difference().inDays` (DST-Fehler, Projekt hat `differenzInTagen`). `istUeberfaellig` ignoriert Toleranz. |
| F5 | Mittel | [`faelligkeit_service.dart`](../lib/features/billing/services/faelligkeit_service.dart) | `istUeberfaellig`: `jetzt.isAfter(faelligAm)` → am Fälligkeitstag selbst ab 00:01 überfällig; inkonsistent zu F4 (`> 0` Tage). |
| F6 | Hoch | [`abrechnung_service.dart`](../lib/features/abrechnung/data/abrechnung_service.dart:72) | `nurAktiveVertraege`: `vertragLaufzeitBis >= now` schließt unbefristete Verträge (`NULL`) aus (SQL-NULL-Vergleich). |
| F7 | Mittel | [`zahlung_service.dart`](../lib/features/billing/services/zahlung_service.dart) | Keine Validierung: `betrag <= 0`, Buchung auf `storniert`en Beleg. `getSingle` auf nicht existente ID wirft unklare Fehler. |
| F8 | Niedrig | [`rechnungsnummer_generator.dart`](../lib/core/data/rechnungsnummer_generator.dart:65) | `R-` und `G-` teilen sich die Tabelle; `MAX`-Abfrage filtert nicht auf Prefix → `G-` und `R-` zählen gemeinsam hoch (Lücken, keine Duplikate). |

## 3. Korrekturen (Zielverhalten)

### F1 – Offene Posten
- Zahlungssummen je Beleg über **eine** aggregierte Query mit `GROUP BY beleg_id` laden
  (`Map<int, double>`), Belege separat laden; Forderung per `leftOuterJoin(preis)` in
  derselben Query statt N+1.
- Pseudocode:
```
summen = select beitragId, SUM(betrag) from zahlungen where beitragId != null group by beitragId
beitraege = select beitrag + preis (leftJoin) where status not in (bezahlt, storniert)
für jeden: rest = runde(preis - (summen[id] ?? 0)); rest > 0.005 → Posten
```
- Analog für Rechnungen; Gutschriften (negativer `betragBrutto`) ergeben `rest <= 0` → ausgeschlossen.

### F2 – Mahnlauf atomar je Mahnung
- Pro Vorschlag eigene verschachtelte `db.transaction` (Savepoint), `try/catch` außerhalb davon.
  Muster identisch zu `AbrechnungService.fuehreAus`.

### F3 – Mahnstufen
- Stufe 4 nur vorschlagen, wenn `tageUeberfaellig >= stufe3FristTage + stufe4Puffer` (neuer Parameter
  `inkassoFristTage`, Default 30) – Konfiguration bleibt Konstante (TODO Stammdaten bleibt).
- Status bei Stufe 4: `inkasso` (Status existiert laut Beitrag-Table-Kommentar); für Rechnungen
  weiterhin `angemahnt` (Rechnungs-Status kennt kein `inkasso`).
- Fristprüfung vereinheitlichen: `frist = konfiguration.fristFuerStufe(stufe)`.

### F4/F5 – Überfälligkeit zentral
- `OffenerPosten.tageUeberfaellig` → `differenzInTagen(faelligAm, DateTime.now())`.
- `FaelligkeitService.istUeberfaellig` → `differenzInTagen(faelligAm, heute) > toleranzTage`.
- `OffenerPosten.istUeberfaellig` bleibt `tageUeberfaellig > 0` (Toleranz = 0 Default, ADR-004).

### F6 – Unbefristete Verträge
- Filter: `vertragLaufzeitBis.isNull() | vertragLaufzeitBis >= heute`.

### F7 – Validierung
- `ArgumentError`/`StateError` bei `betrag <= 0` bzw. Beleg-Status `storniert`; `getSingleOrNull` + klare Meldung.

### F8 – Nummernkreis
- `WHERE rechnungsnummer LIKE '$prefix-%'` mit Parameter-Binding (`Variable`), kein String-Interpolation von Nutzereingaben.

## 4. Tests (Pflicht)
- `test/features/billing/offene_posten_repository_test.dart` (F1, Teilzahlung, Gutschrift)
- `test/features/billing/mahnung_service_test.dart` (F2, F3)
- `test/features/billing/faelligkeit_service_test.dart` (F4, F5, DST-Grenze 2026-10-25)
- Ergänzung `test/features/abrechnung/abrechnung_service_test.dart` (F6)
- `test/features/billing/zahlung_service_test.dart` (F7)
- Ergänzung Rechnungsnummer (F8)

## 5. Randbedingungen
- Keine neuen Packages, keine Schema-Änderung, kein `build_runner` nötig (keine Annotationsänderung).
- 2-Space-Indent, 100 Zeichen, trailing commas; danach `flutter analyze` + `flutter test`.
