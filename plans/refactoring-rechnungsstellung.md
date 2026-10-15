> ⚠️ **ERSETZT** durch [`plans/rechnungsstellung-redesign.md`](rechnungsstellung-redesign.md:1) (2026-10-14). Dieses Dokument bleibt als historische Referenz erhalten.

# Plan: Refactoring – Rechnungsstellung auf Assistent umstellen

> **Status**: Entwurf
> **Erstellt**: 2026-10-12
> **Basiert auf**: [`plans/rechnungsstellung-konzept.md`](rechnungsstellung-konzept.md)
> **Ziel**: Die vier Abrechnungsmodi (Zeitperioden, Einzelmitglied, Auswahl, Kurse)
> umsetzen, alte Code-Teile entfernen, alle Datenintegritätsregeln einhalten.

---

## 1. Ist-Zustand: Doppelte Rechnungslegung (das Problem)

Es existieren **zwei konkurrierende Implementierungen** mit duplizierter Kernlogik
(Duplikat-Prüfung, Preis-Snapshot, Status-Verlauf, Rechnungsnummer):

| Komponente | Alt (wird entfernt) | Neu (wird ausgebaut) |
|---|---|---|
| Dialog | [`RechnungslegungDialog`](../lib/features/beitraege/presentation/dialogs/rechnungslegung_dialog.dart:14) | [`BeitraegeBatchDialog`](../lib/features/rechnungserstellung/presentation/dialogs/beitraege_batch_dialog.dart:20) |
| Service | [`RechnungslegungService`](../lib/features/beitraege/services/rechnungslegung_service.dart:29) | [`BeitraegeBatchService`](../lib/features/rechnungserstellung/services/beitraege_batch_service.dart:36) + Basisklasse [`BatchRechnungService`](../lib/features/rechnungserstellung/services/batch_rechnung_service.dart:15) |
| Result-Model | [`RechnungslegungResult`](../lib/features/beitraege/services/rechnungslegung_service.dart:7) | [`BatchRechnungResult`](../lib/features/rechnungserstellung/domain/models/batch_rechnung_result.dart:5) |
| Einstieg | CreateAction in [`beitraege_screen.dart`](../lib/features/beitraege/beitraege_screen.dart:29) | Menü [`main_menu_bar.dart`](../lib/common_widgets/main_menu_bar.dart:106), Shortcut [`app_shell.dart`](../lib/common_widgets/app_shell.dart:65) |

**Zusätzlich fehlen**: Transaktionen (Batch ohne Atomarität), Einzelmitglied-Modus,
Mehrfachauswahl-Modus, Kurs-Modus, echte Vorschau.

---

## 2. Ziel-Zustand

Ein Rechnungsstellungs-Assistent (`RechnungslegungWizard`) mit vier Modi,
vereinheitlichtem [`AbrechnungService`](#phase-2-service-konsolidierung) und
Transaktions-Sicherheit. Die Struktur folgt
[`plans/rechnungsstellung-konzept.md`](rechnungsstellung-konzept.md) Kap. 5.

### 2.1 Datei-Inventar (komplett)

| Datei | Aktion | Ersetzt durch |
|---|---|---|
| `lib/features/beitraege/presentation/dialogs/rechnungslegung_dialog.dart` | **LÖSCHEN** | [`rechnungslegung_wizard.dart`](../lib/features/rechnungserstellung/presentation/rechnungslegung_wizard.dart) |
| `lib/features/beitraege/services/rechnungslegung_service.dart` | **LÖSCHEN** | [`abrechnung_service.dart`](../lib/features/rechnungserstellung/services/abrechnung_service.dart) |
| `lib/features/rechnungserstellung/presentation/dialogs/beitraege_batch_dialog.dart` | **LÖSCHEN** | Wizard Schritte 1–5 |
| `lib/features/rechnungserstellung/services/beitraege_batch_service.dart` | **AUFLÖSEN** (Logik wandert) | [`abrechnung_service.dart`](../lib/features/rechnungserstellung/services/abrechnung_service.dart) |
| `lib/features/rechnungserstellung/services/batch_rechnung_service.dart` | **AUFLÖSEN** (Basisklasse entfällt, nur noch ein Service) | [`abrechnung_service.dart`](../lib/features/rechnungserstellung/services/abrechnung_service.dart) |
| `lib/features/rechnungserstellung/domain/models/batch_rechnung_result.dart` | **BLEIBT** (Modell konsolidieren: `MemberContractData` ggf. umbenennen) | — |
| `lib/features/rechnungserstellung/domain/models/abrechnungs_modus.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/domain/models/wizard_state.dart` | **NEU** (`@freezed`) | — |
| `lib/features/rechnungserstellung/domain/models/vorschau_zeile.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/services/abrechnung_service.dart` | **NEU** | s. o. |
| `lib/features/rechnungserstellung/presentation/rechnungslegung_wizard.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/presentation/steps/schritt_modus.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/presentation/steps/schritt_auswahl.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/presentation/steps/schritt_zeitraum_optionen.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/presentation/steps/schritt_vorschau.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/presentation/steps/schritt_ergebnis.dart` | **NEU** | — |
| `lib/features/rechnungserstellung/presentation/providers/rechnungslegung_wizard_provider.dart` | **NEU** (`@riverpod`) | — |
| `lib/features/rechnungserstellung/presentation/providers/rechnungslegung_preview_provider.dart` | **NEU** (`@riverpod`) | — |
| `lib/features/beitraege/beitraege_screen.dart` | **ÄNDERN** (CreateAction → Wizard) | — |
| `lib/common_widgets/main_menu_bar.dart` | **ÄNDERN** (Menü → Wizard) | — |
| `lib/common_widgets/app_shell.dart` | **ÄNDERN** (Shortcut → Wizard) | — |
| `lib/assets/data/structur.md` | **ÄNDERN** (SSOT, Screen-Doku Wizard) | — |

---

## 3. Phasenplan

### Phase 0: SSOT & Entscheidung (VOR jeder Code-Änderung)

- [ ] [`lib/assets/data/structur.md`](../lib/assets/data/structur.md:1) aktualisieren:
  - Screen-Sektion `screen_rechnungslegung_wizard` (5 Schritte, Felder, Modi)
  - Rhythmus-Regeln (`leistung.laufzeit` → Periodenbildung, Kap. 4 des Konzepts)
  - Veraltete Dialog-Dokumentation (alter Rechnungslegung-Dialog) markieren/ersetzen
- [ ] ADR [`plans/adr/ADR-001-rechnungsstellungs-assistent.md`](adr/ADR-001-rechnungsstellungs-assistent.md) abzeichnen
- [ ] [`plans/rechnungbatch.md`](rechnungbatch.md) Status auf „ersetzt durch Wizard" setzen

### Phase 1: Domain Models

- [ ] [`abrechnungs_modus.dart`](../lib/features/rechnungserstellung/domain/models/abrechnungs_modus.dart):
  Enum `AbrechnungsModus { zeitperioden, einzelnesMitglied, ausgewaehlteMitglieder, kurse }`
- [ ] [`wizard_state.dart`](../lib/features/rechnungserstellung/domain/models/wizard_state.dart):
  `@freezed`-State (Modus, `mitgliedIds`, `leistungIds`, `von`/`bis`, `zielStatus`, `bemerkung`, Filter-Flags)
- [ ] [`vorschau_zeile.dart`](../lib/features/rechnungserstellung/domain/models/vorschau_zeile.dart):
  Zeile mit `mitgliedId`, `leistungId`, `abrechnungsZeitraum`, `betrag`, `inkludiert`, `ausschlussGrund?`
- [ ] Keine Flutter-Imports in `domain/` (Projektregel)

### Phase 2: Service-Konsolidierung

- [ ] [`abrechnung_service.dart`](../lib/features/rechnungserstellung/services/abrechnung_service.dart) erstellen:
  - `loadCandidates(WizardState)` → modusspezifische Kandidaten-Query:
    - **Zeitperioden**: übernimmt [`loadMembersWithContracts()`](../lib/features/rechnungserstellung/services/batch_rechnung_service.dart:41) aus der Basisklasse
    - **Einzelnes Mitglied**: Mitglied + offene Perioden (Abgleich `abrechnungsZeitraum` gegen gewählten Zeitraum)
    - **Ausgewählte Mitglieder**: Filter `mitgliedId IN (...)`
    - **Kurse**: Filter `leistungId IN (...)`
  - `execute(List<VorschauZeile>, WizardState)`:
    - **Alles in einer `db.transaction(...)`** (Preis-Snapshot → `beitrag` → `beitrag_status_verlauf`) — atomar, Rollback bei Fehler
    - Rechnungsnummer via [`RechnungsnummerGenerator.generateForBeitrag()`](../lib/core/data/rechnungsnummer_generator.dart:20)
    - Initialer Status-Verlauf **mit Bemerkung** (Pflicht, analog zu
      [`BeitraegeBatchService`](../lib/features/rechnungserstellung/services/beitraege_batch_service.dart:147))
  - Duplikat-Prüfung übernimmt [`_getExistingBeitragKeys()`](../lib/features/rechnungserstellung/services/beitraege_batch_service.dart:187) — Schlüssel `mitgliedId + abrechnungsZeitraum` bleibt
  - Rhythmus-Periodenbildung aus `leistung.laufzeit` (Konzept Kap. 4)
- [ ] Logik aus [`BeitraegeBatchService`](../lib/features/rechnungserstellung/services/beitraege_batch_service.dart:36) und
  [`RechnungslegungService`](../lib/features/beitraege/services/rechnungslegung_service.dart:29) **1:1 übernehmen**
  (Preis-Ermittlung: `mitglied.preisId` → Fallback `leistung.preisId`, Snapshot in [`preis`](../lib/core/database/tables/preis_table.dart:1))
- [ ] [`batch_rechnung_service.dart`](../lib/features/rechnungserstellung/services/batch_rechnung_service.dart:15) (Basisklasse) auflösen —
  nur noch ein konkreter Service, Vererbung entfällt (Komposition statt Vererbung, Projektregel)
- [ ] `MemberContractData` ggf. nach `domain/models/` verschieben/umbenennen

### Phase 3: Presentation (Wizard)

- [ ] [`rechnungslegung_wizard.dart`](../lib/features/rechnungserstellung/presentation/rechnungslegung_wizard.dart):
  `HookConsumerWidget` mit Schritt-Navigation (kein `StatefulWidget`, Projektregel)
- [ ] Schritt-Widgets unter `presentation/steps/` (je Widget ≤ eine Verantwortung)
- [ ] [`rechnungslegung_wizard_provider.dart`](../lib/features/rechnungserstellung/presentation/providers/rechnungslegung_wizard_provider.dart):
  `@riverpod`-Notifier für [`WizardState`](../lib/features/rechnungserstellung/domain/models/wizard_state.dart)
- [ ] [`rechnungslegung_preview_provider.dart`](../lib/features/rechnungserstellung/presentation/providers/rechnungslegung_preview_provider.dart):
  `@riverpod` für Vorschau-Berechnung (debounced, `select()` für gezielte Rebuilds)
- [ ] Formularfelder ausschließlich aus [`lib/common_widgets/forms/`](../lib/common_widgets/forms/app_text_field.dart:1)
  ([`AppTextField`](../lib/common_widgets/forms/app_text_field.dart:1),
  [`AppDatePickerField`](../lib/common_widgets/forms/app_date_picker_field.dart:1),
  [`AppDropdownField`](../lib/common_widgets/forms/app_dropdown_field.dart:1))
- [ ] Abstände via `gap`-Package (kein `SizedBox`, Projektregel)
- [ ] Statusfarben nur aus [`beitrag_status_colors.dart`](../lib/features/beitraege/utils/beitrag_status_colors.dart:1)
- [ ] **Code-Generierung (MANDATORISCH)** nach `@riverpod`/`@freezed`:
  `flutter pub run build_runner build -d`

### Phase 4: Alte Code-Teile entfernen & Einstiege umbiegen

- [ ] **Löschen**: [`rechnungslegung_dialog.dart`](../lib/features/beitraege/presentation/dialogs/rechnungslegung_dialog.dart:14)
- [ ] **Löschen**: [`rechnungslegung_service.dart`](../lib/features/beitraege/services/rechnungslegung_service.dart:29)
  (inkl. [`RechnungslegungResult`](../lib/features/beitraege/services/rechnungslegung_service.dart:7) —
  künftig nur [`BatchRechnungResult`](../lib/features/rechnungserstellung/domain/models/batch_rechnung_result.dart:5))
- [ ] **Löschen**: [`beitraege_batch_dialog.dart`](../lib/features/rechnungserstellung/presentation/dialogs/beitraege_batch_dialog.dart:20)
- [ ] **Löschen**: [`beitraege_batch_service.dart`](../lib/features/rechnungserstellung/services/beitraege_batch_service.dart:36)
  und [`batch_rechnung_service.dart`](../lib/features/rechnungserstellung/services/batch_rechnung_service.dart:15)
  (nach Überführung der Logik in Phase 2)
- [ ] **Ändern**: [`beitraege_screen.dart`](../lib/features/beitraege/beitraege_screen.dart:29) —
  CreateAction „Rechnungslegung" öffnet den Wizard mit Modus „Zeitperioden" (Registry-Schlüssel bleibt `'Rechnungslegung'`)
- [ ] **Ändern**: [`main_menu_bar.dart`](../lib/common_widgets/main_menu_bar.dart:106) —
  Menüeintrag öffnet [`RechnungslegungWizard.show(context)`](../lib/features/rechnungserstellung/presentation/rechnungslegung_wizard.dart)
- [ ] **Ändern**: [`app_shell.dart`](../lib/common_widgets/app_shell.dart:65) —
  [`MenuShortcuts.rechnungBeitraege`](../lib/core/keyboard/keyboard_shortcuts.dart) zeigt auf Wizard
- [ ] **Aufräumen**: Alle Imports der gelöschten Dateien entfernen (`flutter analyze` findet sie)

> **Reihenfolge**: Erst Wizard + Service produktiv (Phase 2–3), **dann** Altes löschen (Phase 4).
> Zwischenständig kompiliert das Projekt jederzeit.

### Phase 5: Tests

- [ ] `test/features/rechnungserstellung/abrechnung_service_test.dart`:
  - Duplikat-Prüfung (gleicher Zeitraum wird nicht doppelt erstellt)
  - Rhythmus-Periodenbildung (monatlich/quartalsweise/jaehrlich/einmalig)
  - Preis-Snapshot (Mitgliedspreis vor Kurspreis, Fallback)
  - **Transaktions-Rollback** (Fehler bei Zeile n → keine Beiträge persistiert)
  - Status-Verlauf-Eintrag mit Bemerkung
  - Alle 4 Modi (Kandidaten-Filter)
- [ ] `test/features/rechnungserstellung/wizard_provider_test.dart`:
  State-Übergänge, Vorschau-Auswahl
- [ ] Optional: Widget-Test für Schritt-Navigation
- [ ] Bestehende Tests bleiben grün (`flutter test --coverage`)

### Phase 6: Verifikation & Abschluss

- [ ] `flutter analyze` — keine Warnungen
- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `flutter test --coverage`
- [ ] `flutter pub run build_runner build -d` (falls noch offen)
- [ ] Manueller Smoke-Test gegen `clup_data_dev.sqlite` (Dev-DB, Projekt-Root):
  alle 4 Modi je einmal durchspielen, Vorschau prüfen, Doppelaufruf prüfen (Idempotenz)
- [ ] [`plans/rechnungbatch.md`](rechnungbatch.md) final als „ersetzt" markieren
- [ ] [`lib/assets/data/structur.md`](../lib/assets/data/structur.md:1) gegen Implementierung gegenlesen

---

## 4. Datenintegritäts-Checkliste (Abnahme)

| # | Regel | Quelle | Umsetzung im Refactoring |
|---|---|---|---|
| 1 | SSOT [`structur.md`](../lib/assets/data/structur.md:1) zuerst aktualisiert | AGENTS.md | Phase 0 |
| 2 | Batch-Erstellung atomar (`db.transaction`) | Projektregel | Phase 2 |
| 3 | Status-Verlauf mit **verpflichtender Bemerkung**, nie [`_addStatusEintrag()`](../lib/features/beitraege/data/beitraege_repository.dart) direkt | AGENTS.md | Phase 2 |
| 4 | Statusänderungen via [`updateBeitrag()`](../lib/features/beitraege/data/beitraege_repository.dart:134) | AGENTS.md | Phase 2 |
| 5 | Rechnungsnummern nur via [`RechnungsnummerGenerator`](../lib/core/data/rechnungsnummer_generator.dart:13) (`RE-YYYY-XXXXX`) | AGENTS.md | Phase 2 |
| 6 | Preis-Snapshot in [`preis`](../lib/core/database/tables/preis_table.dart:1), nie Live-Referenz | Schema | Phase 2 |
| 7 | FK: `beitrag.mitglied_id` RESTRICT, `beitrag_status_verlauf` CASCADE — unverändert | AGENTS.md | keine Schema-Änderung |
| 8 | Keine destruktiven Migrationen, forward-only | AGENTS.md | kein Schema-Change im MVP |
| 9 | Keine String-Interpolation in SQL | .roo Regeln | Drift-API bzw. gebundene Variablen |
| 10 | Statusfarben nur [`beitrag_status_colors.dart`](../lib/features/beitraege/utils/beitrag_status_colors.dart:1) | AGENTS.md | Phase 3 |
| 11 | Code-Generierung nach `@riverpod`/`@freezed` | AGENTS.md | Phase 3 |
| 12 | Kein `StatefulWidget`; `HookConsumerWidget` + `flutter_hooks` | AGENTS.md | Phase 3 |
| 13 | `gap` statt `SizedBox`, 2-Space-Einzug, 100 Zeichen | AGENTS.md | Phase 3 |
| 14 | Keine personenbezogenen Daten in Logs (nur IDs) | .roo Regeln | Fehlerbehandlung Phase 2 |
| 15 | NIEMALS destruktive Befehle (`rm -rf`, `DROP TABLE`) | .roo Regeln | Löschen nur via Dateioperationen im Repo |

---

## 5. Risiken & Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| Rechnungsnummern-Kollision im Batch (parallele Generierung) | Generierung + Insert innerhalb derselben Transaktion; Uniqueness-Catch → erneut versuchen |
| Zwischenstand mit toten Imports (gelöschte Dateien) | Löschen erst nach Wizard-Fertigstellung; `flutter analyze` nach jedem Schritt |
| CreateAction-Registry-Schlüssel `'Rechnungslegung'` bricht | Schlüssel beibehalten, nur Action-Ziel tauschen ([`beitraege_screen.dart`](../lib/features/beitraege/beitraege_screen.dart:35)) |
| Vorschau ≠ tatsächlich erstellte Beiträge | Vorschau-Zeilen sind dieselben Objekte, die `execute()` erhält; keine Neuberechnung im Ausführen |
| Regressions bei Status-Verlauf | Bestehende Tests + neue Service-Tests (Phase 5) |

---

## 6. Definition of Done

1. Alle vier Modi sind über **denselben** Wizard erreichbar (Menü, Shortcut, Beiträge-Action)
2. `RechnungslegungDialog`, `RechnungslegungService`, `BeitraegeBatchDialog`,
   `BeitraegeBatchService`, `BatchRechnungService` existieren nicht mehr
3. Keine doppelte Rechnungslegungslogik mehr im Projekt (per `search_files` verifiziert)
4. Batch-Erstellung läuft in einer Transaktion, Rollback getestet
5. [`structur.md`](../lib/assets/data/structur.md:1) dokumentiert den Wizard (SSOT)
6. `flutter analyze`, `dart format --check`, `flutter test` grün
7. Datenintegritäts-Checkliste (Kap. 4) vollständig abgehakt
