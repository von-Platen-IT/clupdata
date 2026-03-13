# Datenstruktur & UI Konfiguration (Single Source of Truth)

> **WICHTIG**: Diese Datei ist die bestimmende Quelle für das Schema der Anwendung.
> **Jeder** Entwickler oder KI-Agent MUSS Änderungen an der Datenbank, Tabellen, Relationen oder zentralen UI-Screens **immer zuerst in dieser Datei** abbilden.

## Metadaten

| Eigenschaft | Wert |
|---|---|
| **version** | 1.0.0 |
| **created** | 2026-02-26 |
| **description** | Schema definition for database structure and UI configuration. Used by AI coding agent to generate database models and UI screens. |
| **file** | lib/assets/data/structur.json |


## 1. Datenbank Tabellen

### 1.1 `bemerkung`
_Generic note/remark entity reused across all tables via FK._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement |  |
| `titel` | TEXT | NotNull, MaxLen:200, Unicode |  |
| `text` | TEXT | MaxLen:10000, Unicode |  |
| `datum_erstellt` | DATETIME | NotNull, Default:CURRENT_TIMESTAMP |  |

### 1.2 `stammdaten`
_Key/value configuration store. Contains global settings like MwSt rate, file paths, app config._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement |  |
| `schluessel` | TEXT | NotNull, Unique, MaxLen:100 | Unique config key, e.g. 'mwst_standard', 'firma_name' |
| `wert` | TEXT |  | Stored as text, parsed according to 'typ' |
| `typ` | TEXT | NotNull, Enum:[string, integer, float, boolean, date] | Data type for correct parsing of 'wert' |
| `kategorie` | TEXT | NotNull, Enum:[finanzen, programm, firma, druck, sonstiges] | Groups settings in the UI |
| `bezeichnung` | TEXT | NotNull, MaxLen:200 | Human-readable label shown in settings UI |
| `beschreibung` | TEXT | MaxLen:500 | Tooltip / help text shown in settings UI |
| `aenderbar` | INTEGER | NotNull, Default:1 | 1 = user may edit, 0 = read-only system value |
| `system_pflicht` | BOOLEAN | NotNull, Default:0 | 1 = mandatory record (cannot be deleted), 0 = optional |

**Initiale Daten (Seed Data):**

| schluessel | wert | typ | kategorie | bezeichnung | aenderbar | system_pflicht |
|---|---|---|---|---|---|---|
| mwst_standard | 19 | float | finanzen | MwSt. Standardsatz (%) | 1 | 1 |
| mwst_ermaessigt | 7 | float | finanzen | MwSt. ermäßigter Satz (%) | 1 | 1 |
| mwst_aktiv_schluessel | mwst_standard | string | finanzen | Verwendeter MwSt.-Schlüssel | 1 | 1 |
| firma_name |  | string | firma | Firmenname | 1 | 1 |
| firma_strasse |  | string | firma | Straße / Hausnummer | 1 | 1 |
| firma_plz |  | string | firma | PLZ | 1 | 1 |
| firma_ort |  | string | firma | Ort | 1 | 1 |
| pfad_export |  | string | programm | Export-Verzeichnis | 1 | 0 |
| pfad_backup |  | string | programm | Backup-Verzeichnis | 1 | 0 |
| db_version | 1 | integer | programm | Datenbankversion | 0 | 1 |

### 1.3 `preis`
_Price entity. Nettopreis is always computed at runtime from bruttopreis and mwst from stammdaten._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement |  |
| `bruttopreis` | REAL | NotNull | Stored value. Always gross. |
| `bemerkung_id` | INTEGER | FK->bemerkung.id(SET NULL) |  |

**Berechnete Felder (Computed):**

| Feld | Formel | Kommentar |
|---|---|---|
| `nettopreis` | `bruttopreis / (1 + stammdaten['mwst_aktiv_schluessel'] / 100)` | NOT stored. Computed at runtime: bruttopreis / (1 + mwst/100). MwSt read from stammdaten.mwst_aktiv_schluessel. |

### 1.4 `leistung`
_Service or membership tier offered to members._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement |  |
| `name` | TEXT | NotNull, MaxLen:200, Unicode |  |
| `preis_id` | INTEGER | NotNull, FK->preis.id(RESTRICT) |  |
| `laufzeit` | TEXT | NotNull, Enum:[einmalig, monatlich, quartalsweise, jaehrlich] | Used to auto-calculate Vertrag_Laufzeit_bis when Vertrag_Laufzeit_von changes |
| `bemerkung_id` | INTEGER | FK->bemerkung.id(SET NULL) |  |

### 1.5 `mitglied`
_Main member entity._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement |  |
| `anrede` | TEXT | Enum:[Herr, Frau, Divers, Keine] |  |
| `name` | TEXT | NotNull, MaxLen:100, Unicode |  |
| `vorname` | TEXT | NotNull, MaxLen:100, Unicode |  |
| `preis_id` | INTEGER | FK->preis.id(SET NULL) |  |
| `plz` | TEXT | MaxLen:10 |  |
| `ort` | TEXT | MaxLen:100, Unicode |  |
| `Strasse` | TEXT | MaxLen:100, Unicode |  |
| `Hausnummer` | TEXT | MaxLen:10 |  |
| `telefon1` | TEXT | MaxLen:50 |  |
| `telefon2` | TEXT | MaxLen:50 |  |
| `email` | TEXT | MaxLen:200 |  |
| `geschlecht` | TEXT | Enum:[maennlich, weiblich, divers] |  |
| `geboren` | DATE |  | Date of birth. Format: ISO 8601 (YYYY-MM-DD) in DB. |
| `leistung_id` | INTEGER | FK->leistung.id(SET NULL) |  |
| `vertrag_kontierung` | DATE |  | Booking/accounting date of the contract. |
| `vertrag_laufzeit_von` | DATE |  |  |
| `vertrag_laufzeit_bis` | DATE |  | Auto-calculated from vertrag_laufzeit_von + leistung.laufzeit. Can be overridden by user. |
| `bemerkung_id` | INTEGER | FK->bemerkung.id(SET NULL) |  |

**Berechnete Felder (Computed):**

| `alter` | `floor(days_between(geboren, today) / 365.25)` | NOT stored. Computed at runtime from 'geboren' and today's date. |

### 1.6 `waren`
_Artikel, Bekleidung und Trainingsgeräte für den Verkauf._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement | Eindeutige technische ID (Korrektur von waren_id). |
| `bezeichnung` | TEXT | NotNull, MaxLen:200, Unicode | Name des Artikels, z.B. "Karate-Gi weiß" |
| `beschreibung` | TEXT | MaxLen:2000, Unicode | Detaillierte Beschreibung, Materialeigenschaften, Pflegehinweise |
| `kategorie` | TEXT | MaxLen:100 | Artikelgruppe, z.B. "Bekleidung", "Schutzausrüstung", "Gürtel" |
| `groesse` | TEXT | MaxLen:50 | Z.B. S, M, L, XL, oder numerische Größen (46, 48) |
| `farbe` | TEXT | MaxLen:50 | Farbe des Artikels (z.B. weiß, blau, rot) |
| `geschlecht` | TEXT | Enum:[Unisex, Herren, Damen, Kinder] | |
| `material` | TEXT | MaxLen:100 | Z.B. Baumwolle, Polyester, Leder |
| `einkaufspreis` | REAL | | Netto-Einkaufspreis pro Einheit (als DECIMAL) |
| `bruttopreis` | REAL | NotNull | Brutto-Verkaufspreis (als DECIMAL) |
| `bestand` | INTEGER | Default:0 | Aktueller Lagerbestand |
| `mindestbestand` | INTEGER | Default:0 | Untergrenze für Nachbestellung |
| `lieferant` | TEXT | MaxLen:200 | Name des Lieferanten |
| `hersteller` | TEXT | MaxLen:200 | Herstellerfirma |
| `hersteller_artikelnr` | TEXT | MaxLen:100 | Hersteller-eigene Artikelnummer |
| `gewicht_kg` | REAL | | Gewicht in kg (z.B. für Versandkosten) |
| `einheit` | TEXT | MaxLen:50 | Verkaufseinheit: "Stück", "Paar", "Set" |
| `bild_url` | TEXT | MaxLen:500 | Pfad/URL zum Produktbild |
| `aktiv` | BOOLEAN | NotNull, Default:1 | 1 = aktiv, 0 = inaktiv |
| `erstellt_am` | DATETIME | NotNull, Default:CURRENT_TIMESTAMP | Zeitpunkt der Anlage |
| `aktualisiert_am` | DATETIME | NotNull, Default:CURRENT_TIMESTAMP | Zeitpunkt der letzten Änderung |
| `bemerkung_id` | INTEGER | FK->bemerkung.id(SET NULL) | Optionale Bemerkung gem. App-Standard |

**Berechnete Felder (Computed):**

| Feld | Formel | Kommentar |
|---|---|---|
| `nettopreis` | `bruttopreis / (1 + stammdaten['mwst_aktiv_schluessel'] / 100)` | NOT stored. Computed at runtime: bruttopreis / (1 + mwst/100). |

### 1.7 `beitrag`
_Rechnung/Zahlung eines Mitglieds für die gebuchten Leistungen._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement | Technical ID |
| `mitglied_id` | INTEGER | NotNull, FK->mitglied.id(RESTRICT) | Member who is billed |
| `leistung_id` | INTEGER | NotNull, FK->leistung.id(RESTRICT) | Billed service/contract |
| `preis_id` | INTEGER | FK->preis.id(SET NULL) | Snapshot of the price at billing |
| `rechnungsnummer` | TEXT | NotNull, Unique, MaxLen:100 | Eindeutige Rechnungsnummer, e.g. "RE-2026-0001" |
| `status` | TEXT | NotNull, Enum:[kontiert, offen, bezahlt, angemahnt, storniert, inkasso] | Current payment status. **VERSIONIERT** in `beitrag_status_verlauf` — Änderungen erfordern einen Eintrag mit Erklärung |
| `kontiert_am` | DATE | NotNull | Date when the contribution/invoice was created and is due |
| `status_datum` | DATE | NotNull | Datum des letzten Statuswechsels (Snapshot, redundant zu Verlauf) |
| `bemerkung_id` | INTEGER | FK->bemerkung.id(SET NULL) | Optionale Bemerkung |

**Status-Versionierung (verbindlich):**
- Jeder Status-Wechsel MUSS in [`beitrag_status_verlauf`](lib/core/database/tables/beitrag_status_verlauf_table.dart:1) protokolliert werden
- Der aktuelle Status wird redundant in `beitrag.status` gespeichert für schnelle Abfragen
- Die Historie ist im Edit-Dialog unter dem Bereich "Status-Historie" einsehbar

### 1.8 `beitrag_status_verlauf`
_Unveränderliche Status-History für einen Beitrag. Jede Statusänderung erzeugt einen neuen Eintrag._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement | Technical ID |
| `beitrag_id` | INTEGER | NotNull, FK->beitrag.id(CASCADE) | Zugehöriger Beitrag — bei Löschung des Beitrags werden alle Verlaufseinträge mitgelöscht |
| `status` | TEXT | NotNull, Enum:[kontiert, offen, bezahlt, angemahnt, storniert, inkasso] | Der neue Status zum Zeitpunkt dieser Änderung |
| `geaendert_am` | DATETIME | NotNull | Exakter Zeitstempel der Statusänderung |
| `bemerkung` | TEXT | NotNull, MaxLen:500 | **PFLICHTFELD**: Erklärung/Grund für die Statusänderung. Darf nicht leer sein. |

**Regeln:**
- Einträge in `beitrag_status_verlauf` sind **READ-ONLY** nach dem Einfügen — sie dürfen niemals geändert oder gelöscht werden (außer durch CASCADE bei Beitrag-Löschung).
- Beim Erstellen eines neuen Beitrags wird automatisch der initiale Status (`kontiert`) als erster Verlaufseintrag mit Bemerkung "Beitrag angelegt" gespeichert.
- Bei jeder manuellen Statusänderung im Dialog MUSS der Benutzer eine Erklärung eingeben, die als `bemerkung` gespeichert wird.
- Die `bemerkung` ist Pflichtfeld (NOT NULL) — dies stellt sicher, dass jede Statusänderung nachvollziehbar ist.

### 1.9 `rechnung`
_Rechnung für Warenverkäufe (POS). Jede Rechnung kann mehrere Positionen haben._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement | Technical ID |
| `rechnungsnummer` | TEXT | NotNull, Unique, MaxLen:100 | Eindeutige Rechnungsnummer, e.g. "R-2026-0001" |
| `mitglied_id` | INTEGER | FK->mitglied.id(SET NULL) | Optional - für Walk-ins kann NULL sein |
| `kunde_name` | TEXT | MaxLen:200 | Name des Kunden (für nicht-Mitglieder) |
| `status` | TEXT | NotNull, Enum:[offen, bezahlt, storniert] | Zahlungsstatus |
| `datum` | DATE | NotNull | Rechnungsdatum |
| `faellig_am` | DATE | NotNull | Fälligkeitsdatum |
| `bezahlt_am` | DATE | | Zahlungsdatum (NULL bis bezahlt) |
| `betrag_netto` | REAL | NotNull | Summe Netto |
| `betrag_brutto` | REAL | NotNull | Summe Brutto |
| `betrag_mwst` | REAL | NotNull | Summe MwSt |
| `bemerkung_id` | INTEGER | FK->bemerkung.id(SET NULL) | Optionale Bemerkung |
| `erstellt_am` | DATETIME | NotNull, Default:CURRENT_TIMESTAMP | Zeitpunkt der Anlage |
| `aktualisiert_am` | DATETIME | NotNull, Default:CURRENT_TIMESTAMP | Letzte Änderung |

**Status-Workflow:**
- `offen` → `bezahlt` (Zahlung eingegangen)
- `offen` → `storniert` (Rechnung storniert)
- `bezahlt` → `storniert` (Stornierung nach Zahlung)

### 1.10 `rechnung_position`
_Positionen (Zeilen) einer Rechnung. Pro Position ein verkaufter Artikel._

| Feld | Typ | Modifikatoren | Kommentar |
|---|---|---|---|
| `id` | INTEGER | PK, AutoIncrement | Technical ID |
| `rechnung_id` | INTEGER | NotNull, FK->rechnung.id(CASCADE) | Zugehörige Rechnung |
| `position_nr` | INTEGER | NotNull | Laufende Nummer 1, 2, 3... |
| `waren_id` | INTEGER | FK->waren.id(SET NULL) | Verkaufter Artikel (NULL wenn gelöscht) |
| `bezeichnung` | TEXT | NotNull, MaxLen:200 | Artikelbezeichnung (Snapshot) |
| `menge` | REAL | NotNull, Default:1 | Anzahl |
| `einzelpreis_netto` | REAL | NotNull | Preis pro Stück Netto |
| `einzelpreis_brutto` | REAL | NotNull | Preis pro Stück Brutto |
| `mwst_satz` | REAL | NotNull | MwSt-Satz in % (z.B. 19.0) |
| `gesamt_netto` | REAL | NotNull | menge * einzelpreis_netto |
| `gesamt_brutto` | REAL | NotNull | menge * einzelpreis_brutto |

**Regeln:**
- Positionen werden bei Löschung der Rechnung automatisch mitgelöscht (CASCADE)
- Preise werden als Snapshot gespeichert (Änderungen an Waren ändern nicht bestehende Rechnungen)

## 2. Datenbank Indizes

| Tabelle | Index Name | Felder | Unique | Kommentar |
|---|---|---|---|---|
| `mitglied` | `idx_mitglied_name` | `name, vorname` | Nein | Full-name search |
| `mitglied` | `idx_mitglied_plz_ort` | `plz, ort` | Nein |  |
| `mitglied` | `idx_mitglied_leistung` | `leistung_id` | Nein |  |
| `mitglied` | `idx_mitglied_vertrag_von` | `vertrag_laufzeit_von` | Nein | Range queries on contract start |
| `mitglied` | `idx_mitglied_vertrag_bis` | `vertrag_laufzeit_bis` | Nein | Expiry queries |
| `mitglied` | `idx_mitglied_geboren` | `geboren` | Nein |  |
| `leistung` | `idx_leistung_name` | `name` | Nein |  |
| `leistung` | `idx_leistung_preis` | `preis_id` | Nein |  |
| `stammdaten` | `idx_stammdaten_schluessel` | `schluessel` | Ja |  |
| `stammdaten` | `idx_stammdaten_kategorie` | `kategorie` | Nein |  |
| `bemerkung` | `idx_bemerkung_datum` | `datum_erstellt` | Nein |  |
| `waren` | `idx_waren_bezeichnung` | `bezeichnung` | Nein |  |
| `waren` | `idx_waren_kategorie` | `kategorie` | Nein |  |
| `waren` | `idx_waren_aktiv` | `aktiv` | Nein |  |
| `beitrag` | `idx_beitrag_rechnungsnummer` | `rechnungsnummer` | Ja |  |
| `beitrag` | `idx_beitrag_mitglied` | `mitglied_id` | Nein |  |
| `beitrag` | `idx_beitrag_status` | `status` | Nein |  |
| `rechnung` | `idx_rechnung_nummer` | `rechnungsnummer` | Ja |  |
| `rechnung` | `idx_rechnung_mitglied` | `mitglied_id` | Nein |  |
| `rechnung` | `idx_rechnung_status` | `status` | Nein |  |
| `rechnung` | `idx_rechnung_datum` | `datum` | Nein |  |
| `rechnung_position` | `idx_rechnung_pos_rechnung` | `rechnung_id` | Nein |  |
| `rechnung_position` | `idx_rechnung_pos_waren` | `waren_id` | Nein |  |


## 3. Relationen

| Von | Nach | Typ | Beschreibung |
|---|---|---|---|
| `mitglied.leistung_id` | `leistung.id` | many-to-one | Mitglied hat eine Leistung |
| `mitglied.bemerkung_id` | `bemerkung.id` | many-to-one | Mitglied hat eine Bemerkung |
| `leistung.preis_id` | `preis.id` | many-to-one | Leistung hat einen Preis |
| `leistung.bemerkung_id` | `bemerkung.id` | many-to-one | Leistung hat eine Bemerkung |
| `preis.bemerkung_id` | `bemerkung.id` | many-to-one | Preis hat eine Bemerkung |
| `waren.bemerkung_id` | `bemerkung.id` | many-to-one | Ware hat eine optionale Bemerkung gem. Standard |
| `beitrag.mitglied_id` | `mitglied.id` | many-to-one | Beitrag gehört zu einem Mitglied |
| `beitrag.leistung_id` | `leistung.id` | many-to-one | Beitrag basiert auf einer Leistung |
| `beitrag.preis_id` | `preis.id` | many-to-one | Preis-Snapshot des Beitrags |
| `beitrag.bemerkung_id` | `bemerkung.id` | many-to-one | Beitrag hat eine optionale Bemerkung |
| `beitrag_status_verlauf.beitrag_id` | `beitrag.id` | many-to-one (CASCADE) | Status-History gehört zu einem Beitrag |
| `rechnung.mitglied_id` | `mitglied.id` | many-to-one (SET NULL) | Rechnung kann zu Mitglied gehören |
| `rechnung.bemerkung_id` | `bemerkung.id` | many-to-one (SET NULL) | Rechnung hat optionale Bemerkung |
| `rechnung_position.rechnung_id` | `rechnung.id` | many-to-one (CASCADE) | Position gehört zu Rechnung |
| `rechnung_position.waren_id` | `waren.id` | many-to-one (SET NULL) | Position referenziert Ware |


## 4. UI Konfiguration

### 4.1 Globale Regeln

- **dataGridPackage**: pluto_grid
- **dataGridPackageUrl**: https://pub.dev/packages/pluto_grid
- **dateDisplayFormat**: dd.MM.yyyy
- **dateDbFormat**: YYYY-MM-DD
- **locale**: de_DE
- **allTablesUseAppDataGrid**: True
- **appDataGridBaseClass**: AppDataGrid
- **appDataGridLocation**: lib/widgets/data_grid/app_data_grid.dart
- **comment**: See datagrid_agent_config.md for full AppDataGrid specification including search, sort dialog and filter dialog.


### 4.2 Screens

#### Screen: Mitglieder (`screen_mitglied_list`)
- **Route**: /mitglieder
- **Typ**: dataGridScreen
- **Datenquelle**: `mitglied`
- **Data Grid Konfiguration:**
  - Spalte `name` (Name) - text - Sort:True Filter:True
  - Spalte `vorname` (Vorname) - text - Sort:True Filter:True
  - Spalte `ort` (Ort) - text - Sort:True Filter:True
  - Spalte `telefon1` (Telefon) - text - Sort:False Filter:True
  - Spalte `email` (E-Mail) - text - Sort:False Filter:True
  - Spalte `leistung_name` (Vertragsart) - text - Sort:True Filter:True
  - Spalte `beitrag` (Beitrag) - text - Sort:True Filter:True

#### Screen: Mitglied bearbeiten (`screen_mitglied_edit`)
- **Route**: /mitglieder/edit
- **Typ**: formScreen
- **Datenquelle**: `mitglied`
- **Formular Bereiche:**
  - **Person**
    - `anrede` (Anrede) - Widget: DropdownField
    - `vorname` (Vorname) - Widget: TextField
    - `name` (Name) - Widget: TextField
    - `geboren` (Geburtsdatum) - Widget: DateField
    - `alter` (Alter) - Widget: ReadOnlyField
    - `geschlecht` (Geschlecht) - Widget: DropdownField
  - **Kontakt**
    - `plz` (PLZ) - Widget: TextField
    - `ort` (Ort) - Widget: TextField
    - `telefon1` (Telefon 1) - Widget: TextField
    - `telefon2` (Telefon 2) - Widget: TextField
    - `email` (E-Mail) - Widget: TextField
  - **Vertrag**
    - `vertrag_start_action` () - Widget: ElevatedButton
    - `vertrag_kontierung` (Kontierung) - Widget: DateField
    - `leistung_id` (Leistung) - Widget: ReadOnlyDisplayField
    - `vertrag_laufzeit_von` (Laufzeit von) - Widget: DateField
    - `vertrag_laufzeit_bis` (Laufzeit bis) - Widget: DateField
  - **Bemerkung**
    - `bemerkung_titel` (Titel) - Widget: TextField
    - `bemerkung_text` (Text) - Widget: TextAreaField

#### Screen: Leistungen (`screen_leistung_list`)
- **Route**: /leistungen
- **Typ**: dataGridScreen
- **Datenquelle**: `leistung`
- **Data Grid Konfiguration:**
  - Spalte `name` (Name) - text - Sort:True Filter:True
  - Spalte `laufzeit` (Laufzeit) - text - Sort:True Filter:True
  - Spalte `bruttopreis` (Brutto (€)) - number - Sort:True Filter:False
  - Spalte `nettopreis` (Netto (€)) - number - Sort:False Filter:False

#### Screen: Leistung bearbeiten (`screen_leistung_edit`)
- **Route**: /leistungen/edit
- **Typ**: formScreen
- **Datenquelle**: `leistung`
- **Formular Bereiche:**
  - **Leistung**
    - `name` (Name) - Widget: TextField
    - `laufzeit` (Laufzeit) - Widget: DropdownField
  - **Preis**
    - `bruttopreis` (Bruttopreis (€)) - Widget: CurrencyField
    - `nettopreis` (Nettopreis (€)) - Widget: ReadOnlyField
  - **Bemerkung**
    - `bemerkung_titel` (Titel) - Widget: TextField
    - `bemerkung_text` (Text) - Widget: TextAreaField

#### Screen: Stammdaten / Einstellungen (`screen_stammdaten`)
- **Route**: /stammdaten
- **Typ**: configScreen
- **Datenquelle**: `stammdaten`
- **Kommentar**: Grouped by 'kategorie'. Only rows with aenderbar=1 are editable.

#### Screen: Waren (`screen_waren_list`)
- **Route**: /waren
- **Typ**: dataGridScreen
- **Datenquelle**: `waren`
- **Data Grid Konfiguration:**
  - Spalte `bezeichnung` (Bezeichnung) - text - Sort:True Filter:True
  - Spalte `kategorie` (Kategorie) - text - Sort:True Filter:True
  - Spalte `bestand` (Bestand) - number - Sort:True Filter:True
  - Spalte `bruttopreis` (Brutto (€)) - number - Sort:True Filter:False
  - Spalte `nettopreis` (Netto (€)) - number - Sort:False Filter:False
  - Spalte `aktiv` (Aktiv) - boolean - Sort:True Filter:True

#### Screen: Ware bearbeiten (`screen_ware_edit`)
- **Route**: /waren/edit
- **Typ**: formScreen
- **Datenquelle**: `waren`
- **Formular Bereiche:**
  - **Allgemein**
    - `bezeichnung` (Bezeichnung) - Widget: TextField
    - `kategorie` (Kategorie) - Widget: TextField
    - `beschreibung` (Beschreibung) - Widget: TextAreaField
    - `aktiv` (Aktiv) - Widget: CheckboxField
  - **Eigenschaften**
    - `groesse` (Größe) - Widget: TextField
    - `farbe` (Farbe) - Widget: TextField
    - `geschlecht` (Geschlecht) - Widget: DropdownField
    - `material` (Material) - Widget: TextField
    - `gewicht_kg` (Gewicht (kg)) - Widget: TextField
    - `einheit` (Einheit) - Widget: TextField
  - **Preise & Bestand**
    - `einkaufspreis` (Einkaufspreis (€)) - Widget: CurrencyField
    - `bruttopreis` (Bruttopreis (€)) - Widget: CurrencyField
    - `nettopreis` (Nettopreis (€)) - Widget: ReadOnlyField
    - `bestand` (Bestand) - Widget: TextField
    - `mindestbestand` (Mindestbestand) - Widget: TextField
  - **Logistik & Hersteller**
    - `lieferant` (Lieferant) - Widget: TextField
    - `hersteller` (Hersteller) - Widget: TextField
    - `hersteller_artikelnr` (Artikelnr. HF) - Widget: TextField
  - **Bemerkung**
    - `bemerkung_titel` (Titel) - Widget: TextField
    - `bemerkung_text` (Text) - Widget: TextAreaField

#### Screen: Beiträge (`screen_beitrag_list`)
- **Route**: /beitraege
- **Typ**: dataGridScreen
- **Datenquelle**: `beitrag`
- **Data Grid Konfiguration:**
  - Spalte `rechnungsnummer` (Rechnungs-Nr.) - text - Sort:True Filter:True
  - Spalte `mitglied_name` (Mitglied) - text - Sort:True Filter:True
  - Spalte `leistung_name` (Leistung) - text - Sort:True Filter:True
  - Spalte `kontiert_am` (Kontiert am) - date - Sort:True Filter:True
  - Spalte `status` (Status) - text - Sort:True Filter:True — **Zeilenfarbe gemäß Statusfarben-Tabelle**
  - Spalte `status_datum` (Statusdatum) - date - Sort:True Filter:True

**Statusfarben (VERBINDLICH für UI und Datenbank-Views):**

| Status | Farbe | Hex | Verwendung |
|---|---|---|---|
| `kontiert` | Hellgelb | `#FFF9C4` | Neu angelegte Beiträge |
| `offen` | Hellorange | `#FFE0B2` | Fällige, ausstehende Zahlungen |
| `bezahlt` | Hellgrün | `#C8E6C9` | Vollständig bezahlte Beiträge |
| `angemahnt` | Hellrot | `#FFCDD2` | Zahlungserinnerung versandt |
| `storniert` | Hellgrau | `#EEEEEE` | Stornierte Rechnungen |
| `inkasso` | Pink | `#F8BBD0` | An Inkasso übergeben |

**Farb-Verwendungsregeln (zwingend):**
1. **DataGrid-Zeilen**: Jede Zeile MUSS die Hintergrundfarbe gemäß ihres Status erhalten
2. **Status-Badge**: Der Status-Text in der Status-Spalte MUSS als farbiges Badge dargestellt werden
3. **Edit-Dialog**: Das Status-Dropdown MUSS die jeweilige Farbe als Hintergrund des ausgewählten Werts anzeigen
4. **Zentrale Quelle**: ALLE Farben MÜSSEN aus [`lib/features/beitraege/utils/beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart:1) bezogen werden
5. **Konsistenz**: Die Hex-Werte dürfen NICHT an anderen Stellen hartkodiert werden

> **WICHTIG**: Diese Farben sind Teil der UX-Spezifikation. Änderungen erfordern ein Update dieser Dokumentation UND aller referenzierenden Dateien.

#### Screen: Beitrag bearbeiten (`screen_beitrag_edit`)
- **Route**: /beitraege/edit
- **Typ**: formScreen
- **Datenquelle**: `beitrag`
- **Formular Bereiche:**
  - **Beitrag / Rechnung**
    - `rechnungsnummer` (Rechnungs-Nr.) - Widget: ReadOnlyField
    - `mitglied_id` (Mitglied) - Widget: DropdownField (or SearchableSelect)
    - `leistung_id` (Leistung) - Widget: ReadOnlyDisplayField
    - `preis_id` (Preis) - Widget: ReadOnlyDisplayField
  - **Status & Daten**
    - `status` (Status) - Widget: DropdownField
    - `kontiert_am` (Kontiert am) - Widget: DateField
    - `status_datum` (Statusdatum) - Widget: ReadOnlyField
  - **Bemerkung**
    - `bemerkung_titel` (Titel) - Widget: TextField
    - `bemerkung_text` (Text) - Widget: TextAreaField

### 4.3 Dialoge

#### Dialog: Neuer Beitrag (`dialog_beitrag_new`)
- **Typ**: modalDialog
- **Kommentar**: Dialog zum Erstellen eines neuen Beitrags/Rechnung. Die Rechnungsnummer wird automatisch generiert und ist nicht prominent platziert.
- **Felder:**
  - `rechnungsnummer` (Rechnungs-Nr.) - Widget: ReadOnlyField - kleine, dezente Darstellung oben rechts
  - `mitglied_search` (Mitglied suchen) - Widget: AutocompleteField - Suche über Vor- und Nachname
  - `mitglied_selected` (Ausgewähltes Mitglied) - Widget: InfoCard - zeigt Name, PLZ, Ort
  - `leistung_search` (Leistung suchen) - Widget: AutocompleteField - Suche über Leistungsnamen
  - `leistung_selected` (Ausgewählte Leistung) - Widget: InfoCard - zeigt Name, Laufzeit, Standardpreis
  - `beitrag` (Beitrag €) - Widget: CurrencyField - übernimmt Preis aus Mitglied, aber überschreibbar
  - `kontiert_am` (Kontiert am) - Widget: DateField - Standard: heute
  - `status` (Status) - Widget: StatusBadge - immer "kontiert" mit gelber Farbe
- **Validierung:**
  - Mitglied ist Pflichtfeld
  - Leistung ist Pflichtfeld
  - Beitrag muss > 0 sein
- **Logik:**
  - Rechnungsnummer-Format: `RE-YYYY-XXXXX` (Jahr + 5-stellige laufende Nummer)
  - Beitrag wird automatisch aus `mitglied.preis_id` geladen
  - Status wird automatisch auf "kontiert" gesetzt
  - Initialer Verlaufseintrag wird automatisch erstellt

#### Screen: Rechnungen (`screen_rechnung_list`)
- **Route**: /rechnungen
- **Typ**: dataGridScreen
- **Datenquelle**: `rechnung`
- **Data Grid Konfiguration:**
  - Spalte `rechnungsnummer` (Rechnungs-Nr.) - text - Sort:True Filter:True
  - Spalte `kunde_name` (Kunde) - text - Sort:True Filter:True
  - Spalte `datum` (Datum) - date - Sort:True Filter:True
  - Spalte `betrag_brutto` (Betrag €) - number - Sort:True Filter:False
  - Spalte `status` (Status) - text - Sort:True Filter:True — **Zeilenfarbe gemäß Status**

**Statusfarben für Rechnungen:**

| Status | Farbe | Hex | Verwendung |
|---|---|---|---|
| `offen` | Hellorange | `#FFE0B2` | Ausstehende Zahlung |
| `bezahlt` | Hellgrün | `#C8E6C9` | Bezahlte Rechnungen |
| `storniert` | Hellgrau | `#EEEEEE` | Stornierte Rechnungen |

#### Screen: Rechnung bearbeiten (`screen_rechnung_edit`)
- **Route**: /rechnungen/edit
- **Typ**: formScreen
- **Datenquelle**: `rechnung`
- **Formular Bereiche:**
  - **Rechnung**
    - `rechnungsnummer` (Rechnungs-Nr.) - Widget: ReadOnlyField
    - `status` (Status) - Widget: DropdownField
    - `datum` (Rechnungsdatum) - Widget: DateField
    - `faellig_am` (Fällig am) - Widget: DateField
    - `bezahlt_am` (Bezahlt am) - Widget: DateField (nur bei Status=bezahlt)
  - **Kunde**
    - `mitglied_id` (Mitglied) - Widget: SearchableSelect (optional)
    - `kunde_name` (Kundenname) - Widget: TextField (für Walk-ins)
  - **Positionen**
    - `positionen_list` (Artikel) - Widget: DataTable/EditableList
    - `position_add` (Artikel hinzufügen) - Widget: Button + SearchDialog
  - **Summen**
    - `betrag_netto` (Netto €) - Widget: ReadOnlyField
    - `betrag_mwst` (MwSt €) - Widget: ReadOnlyField
    - `betrag_brutto` (Brutto €) - Widget: ReadOnlyField (fett/hervorgehoben)
  - **Bemerkung**
    - `bemerkung_titel` (Titel) - Widget: TextField
    - `bemerkung_text` (Text) - Widget: TextAreaField

#### Dialog: Neue Rechnung (`dialog_rechnung_new`)
- **Typ**: modalDialog
- **Kommentar**: Dialog zum Erstellen einer neuen Rechnung für Warenverkäufe. Ähnelt dem POS-Workflow.
- **Felder:**
  - `rechnungsnummer` (Rechnungs-Nr.) - Widget: ReadOnlyField - kleine Darstellung oben rechts
  - `mitglied_search` (Mitglied suchen) - Widget: AutocompleteField - optional
  - `kunde_name` (Kundenname) - Widget: TextField - für Walk-ins
  - `datum` (Rechnungsdatum) - Widget: DateField - Standard: heute
  - **Positionen**
    - `ware_search` (Artikel suchen) - Widget: AutocompleteField + Lupe für Warenliste
    - `waren_liste` (Positionen) - Widget: EditableList mit Menge/Preis/Delete
  - **Summen**
    - `betrag_netto` (Netto €) - Widget: ReadOnlyField
    - `betrag_mwst` (MwSt €) - Widget: ReadOnlyField
    - `betrag_brutto` (Brutto €) - Widget: ReadOnlyField
- **Validierung:**
  - Mindestens eine Position muss vorhanden sein
  - Menge muss > 0 sein
  - Entweder Mitglied ODER Kundenname muss angegeben sein
- **Logik:**
  - Rechnungsnummer-Format: `R-YYYY-XXXXX` (Jahr + 5-stellige laufende Nummer)
  - Status wird automatisch auf "offen" gesetzt
  - MwSt wird aus Stammdaten (mwst_aktiv_schluessel) ermittelt
  - Preise werden als Snapshot gespeichert

#### Dialog: Vertrag starten (`dialog_mitglied_vertrag_start`)
- **Typ**: modalDialog
- **Kommentar**: Opened by the 'Start' button in the member form or member list. Sets kontierung date and selects Leistung. Auto-calculates Laufzeit bis.
- **Felder:**
  - `vertrag_kontierung` (Kontierungsdatum) - Widget: DateField
  - `leistung_id` (Leistung) - Widget: DropdownField
  - `vertrag_laufzeit_von` (Laufzeit von) - Widget: DateField
  - `vertrag_laufzeit_bis` (Laufzeit bis) - Widget: DateField
