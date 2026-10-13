# Plan: Schnellerfassung – Massen-Eingabe mit Vorlagen

> **Status**: Entwurf
> **Erstellt**: 2026-10-13
> **Schema-Version**: 18 (KEINE Schema-Änderung – Vorlagen in `stammdaten` als JSON)
> **Zielgruppe**: Erstbefüllung – Anwender müssen zu Beginn viele Datensätze
> (z. B. 200 Mitglieder mit Verträgen) manuell einpflegen.

---

## 1. Problemanalyse

**Heute**: Pro Datensatz ein Einzel-Dialog („Neues Mitglied") – öffnen, Felder
füllen, speichern, schließen, neu beginnen. Bei 200 Mitgliedern sind das ~800
Klicks. Immergleiche Angaben (PLZ, Ort, Leistung, Vertragsbeginn) werden bei
jedem Datensatz neu erfasst.

**Ziel**: Ein Eingabe-Arbeitsbereich, der auf **Wiederholung** optimiert ist:
so wenig Aktionen wie möglich zwischen zwei Datensätzen, intelligente
Vorbelegung, klare Rückmeldung.

## 2. Recherche: Bewährte Muster aus anderer Software

> Hinweis: Das Context7-Recherche-Tool stand nicht zur Verfügung; die Analyse
> basiert auf etablierten Mustern aus Warenwirtschaft, Kassensystemen
> (SAP „Beleg kopieren", Lexware Schnellerfassung), Notion/Excel-Listen-Eingabe
> und POS-Systemen.

| Muster | Beschreibung | Nutzen für ClupData |
|---|---|---|
| **Speichern & weiter** | Nach dem Speichern bleibt das Formular offen, Fokus springt ins erste Feld | Kern der Schnellerfassung |
| **Letzte Eingabe als Vorlage** | Komfortfelder (Ort, Leistung …) bleiben gefüllt, Personenfelder werden geleert | „Wie eben" – ohne Klick |
| **Benannte Vorlagen** | Gespeicherte Wertekombinationen („Erwachsene Boxen", „Familienkind") | Ein-Klick-Vorbelegung |
| **Von vorhandenem Datensatz** | Bestehenden Datensatz suchen, Felder übernehmen | „Wie Familie Müller, aber …" |
| **Erfassungs-Protokoll** | Sichtbare Liste der Sitzung als Kontrolle + Motivation | Rechte Seitenleiste |
| **Duplikat-Warnung** | Ähnlicher Datensatz erkannt → Warnung vor Doppelerfassung | Qualität bei Masseneingabe |
| **Tastatur-Workflow** | Strg+Enter = speichern, Enter = nächstes Feld | Tempo ohne Maus |

## 3. Lösungskonzept: „Schnellerfassung"

### 3.1 Drei Vorlagen-Mechanismen

1. **Benannte Vorlagen (persistent)**
   - „Als Vorlage speichern…" → Name eingeben → in [`stammdaten`](../lib/assets/data/structur.md:72)
     als JSON gespeichert (`vorlage_mitglied_<slug>`)
   - Vorlage laden/löschen über eine Auswahlliste
2. **Auto-Vorlage (Sitzung)**: Nach **„Speichern & Felder behalten"** bleiben
   Komfortfelder gefüllt, Personenfelder werden geleert:
   - **bleiben**: Anrede, PLZ, Ort, Strasse, Leistung, Vertragsbeginn,
     Vertragslaufzeit, Geschlecht
   - **werden geleert**: Name, Vorname, Geburtsdatum, Telefon, E-Mail
3. **Von vorhandenem Datensatz**: Suche über Mitglieder → Klick übernimmt alle
   Felder (Name/Vorname werden zum Bearbeiten geleert)

### 3.2 Datenspeicherung der Vorlagen (kein Schema-Change)

| Schlüssel | Wert | Beschreibung |
|---|---|---|
| `vorlage_mitglied_<slug>` | JSON-Map der Felder | Eine benannte Vorlage |

- Typ `string`, Kategorie `programm`, änderbar – analog zum Backup-Konzept
  ([`ADR-003`](adr/ADR-003-backup-konzept.md)-Muster: `getOrCreate`, kein Migrationsaufwand)
- Löschen = Schlüssel entfernen; Auflisten = Präfix-Scan `vorlage_mitglied_`

---

## 4. UI: Schnellerfassung (Route `/schnellerfassung`)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Schnellerfassung – Mitglieder                                       [X]  │
├──────────────────────────────────────────────────────────────────────────┤
│  Vorlage: [Erwachsene Boxen ▼]  [Als Vorlage speichern…]  [Löschen]       │
│            [Von vorhandenem Datensatz übernehmen…]                        │
├──────────────────────────────────────────┬───────────────────────────────┤
│  ── Person ──────────────────────────    │  Erfasst in dieser Sitzung (3)│
│  Anrede [Frau ▼]  Geschlecht [▼]         │  ┌─────────────────────────┐  │
│  Name [_____________] *                  │  │ 1  Mustermann, Maria    │  │
│  Vorname [__________] *                  │  │ 2  Beispiel, Hans       │  │
│  Geboren [ 01.01.1990 ]                  │  │ 3  Muster, Erika        │  │
│  ── Kontakt ─────────────────────────    │  └─────────────────────────┘  │
│  PLZ [____] Ort [______________]         │  [Liste leeren]               │
│  Strasse [____________] Nr. [____]       │                               │
│  Telefon [____________]                  │  ⚠ Möglicher Duplikat:        │
│  E-Mail [_________________________]      │  „Mustermann, Maria" wurde     │
│  ── Vertrag ─────────────────────────    │  kürzlich angelegt            │
│  Leistung [Boxen Erwachsene ▼] *         │                               │
│  Vertrag beginnt am [ 01.10.2026 ]       │  Sitzung: 3 Datensätze        │
│  ── Bemerkung ───────────────────────    │  Gesamt heute: 3              │
│  Bemerkung [______________________]      │                               │
├──────────────────────────────────────────┴───────────────────────────────┤
│  [Speichern & leeren  (Strg+Enter)]  [Speichern & Felder behalten]        │
└──────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Bedienkonzept

| Aktion | Verhalten |
|---|---|
| **Speichern & leeren** (Strg+Enter) | Datensatz anlegen, Formular komplett leeren, Fokus auf „Name" |
| **Speichern & Felder behalten** | Datensatz anlegen, Personenfelder leeren, Komfortfelder behalten |
| **Vorlage auswählen** | Sofortige Befüllung aller Felder aus der Vorlage |
| **Als Vorlage speichern…** | Dialog für Vorlagen-Name, aktuelle Feldwerte werden gespeichert |
| **Von vorhandenem Datensatz übernehmen…** | Suchdialog → Felder werden befüllt (Name/Vorname werden geleert) |
| **Duplikat-Warnung** | Bei Namensgleichheit (Sitzung ODER Datenbank) erscheint ein Hinweis in der Seitenleiste – nicht blockierend, nur informativ |

### 4.2 Ergonomie-Details

- **Pflichtfelder** sind mit `*` markiert (Name, Vorname, Leistung)
- **Validierung** direkt am Feld; Speichern nur bei gültigen Pflichtfeldern
- **Fokus-Reset** nach dem Speichern auf das erste Pflichtfeld
- **Zähler** („Erfasst in dieser Sitzung") als Fortschritts-Feedback
- **Leistung-Dropdown** zeigt nur aktive Vertragsarten
- Feldgruppen (Person/Kontakt/Vertrag) helfen bei der Orientierung

---

## 5. Architektur

```
lib/features/schnellerfassung/
├── data/
│   └── vorlage_repository.dart        # NEU: Vorlagen-CRUD (stammdaten JSON)
├── domain/models/
│   ├── vorlage.dart                   # NEU (@freezed: name, schluessel, felder)
│   └── schnellerfassung_felder.dart   # NEU (@freezed: Formularfelder + Kopierlogik)
├── presentation/
│   ├── schnellerfassung_screen.dart   # NEU (Screen, Route /schnellerfassung)
│   ├── providers/
│   │   └── schnellerfassung_providers.dart  # NEU (@riverpod)
│   └── widgets/
│       ├── vorlage_leiste.dart        # NEU (Vorlage wählen/speichern/übernehmen)
│       ├── mitglied_schnell_formular.dart   # NEU (Eingabeformular)
│       └── erfasste_liste.dart        # NEU (Protokoll + Duplikat-Warnung)
└── services/
    └── schnellerfassung_service.dart  # NEU: Speichern (addMember) + Duplikat-Check
```

**Anbindung:**
- [`MembersRepository.addMember()`](../lib/features/members/data/members_repository.dart:103)
  für das Speichern (bewährter Pfad des Einzel-Dialogs)
- [`StammdatenRepository`](../lib/features/stammdaten/data/stammdaten_repository.dart:7)
  als Storage für Vorlagen (getOrCreate-Muster wie
  [`BackupConfigRepository`](../lib/features/backup/data/backup_config_repository.dart:18))
- Route `/schnellerfassung` in [`app_router.dart`](../lib/core/router/app_router.dart:1);
  Einstieg über das **Erstellen-Menü** („Schnellerfassung Mitglieder")

---

## 6. Umsetzungsreihenfolge

1. ✅ Analyse + Konzept (dieser Plan)
2. [`vorlage.dart`](../lib/features/schnellerfassung/domain/models/vorlage.dart),
   [`schnellerfassung_felder.dart`](../lib/features/schnellerfassung/domain/models/schnellerfassung_felder.dart) (Freezed-Modelle)
3. [`vorlage_repository.dart`](../lib/features/schnellerfassung/data/vorlage_repository.dart)
   (JSON in `stammdaten`, Präfix-Scan, CRUD) + Provider
4. [`schnellerfassung_service.dart`](../lib/features/schnellerfassung/services/schnellerfassung_service.dart)
   (addMember, Duplikat-Prüfung, Auto-Vorlage-Logik)
5. UI: [`vorlage_leiste.dart`](../lib/features/schnellerfassung/presentation/widgets/vorlage_leiste.dart),
   [`mitglied_schnell_formular.dart`](../lib/features/schnellerfassung/presentation/widgets/mitglied_schnell_formular.dart),
   [`erfasste_liste.dart`](../lib/features/schnellerfassung/presentation/widgets/erfasste_liste.dart),
   [`schnellerfassung_screen.dart`](../lib/features/schnellerfassung/presentation/schnellerfassung_screen.dart)
6. Routing + Erstellen-Menü-Eintrag
7. Tests: Vorlagen-CRUD (JSON-Roundtrip, Präfix-Scan), Auto-Vorlage-Kopierlogik,
   Duplikat-Erkennung
8. Verifikation (build_runner, analyze, tests)

---

## 7. Offene Punkte

| # | Frage | Entscheidung |
|---|---|---|
| 1 | Auch für Waren/Leistungen? | Architektur generisch (Vorlage = JSON-Map + Entitätspräfix), MVP = **Mitglieder** (Kernproblem Erstbefüllung) |
| 2 | Ziel-Anzahl-Vorgabe („12 von 200")? | Nicht Teil des MVP – die Sitzungszähler reichen als Feedback |
| 3 | CSV-Import als Alternative? | Besteht bereits ([`12_datenuebertragung.md`](../lib/assets/docs/12_datenuebertragung.md)); die Schnellerfassung ergänzt ihn für manuelle/unklare Daten |
