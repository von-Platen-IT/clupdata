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
| `typ` | TEXT | NotNull, Enum:[string, number, boolean, date] | Data type for correct parsing of 'wert' |
| `kategorie` | TEXT | NotNull, Enum:[finanzen, programm, firma, druck, sonstiges] | Groups settings in the UI |
| `bezeichnung` | TEXT | NotNull, MaxLen:200 | Human-readable label shown in settings UI |
| `beschreibung` | TEXT | MaxLen:500 | Tooltip / help text shown in settings UI |
| `aenderbar` | INTEGER | NotNull, Default:1 | 1 = user may edit, 0 = read-only system value |

**Initiale Daten (Seed Data):**

| schluessel | wert | typ | kategorie | bezeichnung | aenderbar |
|---|---|---|---|---|---|
| mwst_standard | 19 | number | finanzen | MwSt. Standardsatz (%) | 1 |
| mwst_ermaessigt | 7 | number | finanzen | MwSt. ermäßigter Satz (%) | 1 |
| mwst_aktiv_schluessel | mwst_standard | string | finanzen | Verwendeter MwSt.-Schlüssel | 1 |
| firma_name |  | string | firma | Firmenname | 1 |
| firma_strasse |  | string | firma | Straße / Hausnummer | 1 |
| firma_plz |  | string | firma | PLZ | 1 |
| firma_ort |  | string | firma | Ort | 1 |
| pfad_export |  | string | programm | Export-Verzeichnis | 1 |
| pfad_backup |  | string | programm | Backup-Verzeichnis | 1 |
| db_version | 1 | number | programm | Datenbankversion | 0 |

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


## 3. Relationen

| Von | Nach | Typ | Beschreibung |
|---|---|---|---|
| `mitglied.leistung_id` | `leistung.id` | many-to-one | Mitglied hat eine Leistung |
| `mitglied.bemerkung_id` | `bemerkung.id` | many-to-one | Mitglied hat eine Bemerkung |
| `leistung.preis_id` | `preis.id` | many-to-one | Leistung hat einen Preis |
| `leistung.bemerkung_id` | `bemerkung.id` | many-to-one | Leistung hat eine Bemerkung |
| `preis.bemerkung_id` | `bemerkung.id` | many-to-one | Preis hat eine Bemerkung |
| `waren.bemerkung_id` | `bemerkung.id` | many-to-one | Ware hat eine optionale Bemerkung gem. Standard |


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
  - Spalte `vertrag_laufzeit_von` (Laufzeit von) - date - Sort:True Filter:True
  - Spalte `vertrag_laufzeit_bis` (Laufzeit bis) - date - Sort:True Filter:True
  - Spalte `alter` (Alter) - number - Sort:True Filter:False

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

### 4.3 Dialoge

#### Dialog: Vertrag starten (`dialog_mitglied_vertrag_start`)
- **Typ**: modalDialog
- **Kommentar**: Opened by the 'Start' button in the member form or member list. Sets kontierung date and selects Leistung. Auto-calculates Laufzeit bis.
- **Felder:**
  - `vertrag_kontierung` (Kontierungsdatum) - Widget: DateField
  - `leistung_id` (Leistung) - Widget: DropdownField
  - `vertrag_laufzeit_von` (Laufzeit von) - Widget: DateField
  - `vertrag_laufzeit_bis` (Laufzeit bis) - Widget: DateField
