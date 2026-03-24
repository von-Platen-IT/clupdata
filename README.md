# ClupData - Boxing Club Management System

Ein Desktop-Verwaltungssystem (Windows/macOS/Linux) für einen Boxclub. Diese Anwendung bietet eine umfassende Lösung zur Verwaltung von Mitgliedern, Verträgen, Beiträgen, Warenwirtschaft und Rechnungsstellung.

## 🚀 Features

### Mitgliederverwaltung
- **Mitglieder-Profil:** Stammdaten, Kontaktdaten, Geburtsdatum, Geschlecht
- **Vertragsmanagement:** Vertragslaufzeiten, automatische Laufzeitberechnung
- **Leistungszuordnung:** Jedem Mitglied kann eine Vertragsart (Leistung) zugeordnet werden
- **Schnellsuche:** Volltextsuche über alle Mitgliedsdaten
- **DataGrid-Ansicht:** Übersichtliche tabellarische Darstellung mit Sortierung und Filterung

### Leistungskatalog
- **Vertragsarten:** Definition verschiedener Mitgliedschaftsarten
- **Preisgestaltung:** Brutto/Netto-Preise mit automatischer MwSt-Berechnung
- **Laufzeiten:** Einmalig, monatlich, quartalsweise, jährlich
- **Mitgliedszuordnung:** Übersicht welche Mitglieder welche Leistung gebucht haben

### Beitragsverwaltung
- **Status-Tracking:** Kontiert → Offen → Bezahlt/Angemahnt/Storniert/Inkasso
- **Farbkodierung:** Jeder Status hat eine eindeutige Farbe für visuelle Unterscheidung
- **Status-Historie:** Jede Statusänderung wird mit Zeitstempel und Bemerkung protokolliert
- **Rechnungslegung:** Massenerstellung von Beiträgen für alle Mitglieder mit gültigem Vertrag
- **Automatische Nummerierung:** Rechnungsnummern im Format `RE-YYYY-XXXXX`

### Warenwirtschaft (Inventory)
- **Artikelverwaltung:** Bezeichnung, Kategorie, Größe, Farbe, Material
- **Lagerverwaltung:** Bestand, Mindestbestand, Einheiten
- **Preisgestaltung:** Einkaufspreis, Brutto/Netto-Verkaufspreis
- **Lieferanten:** Hersteller, Lieferant, Artikelnummern
- **Aktiv/Inaktiv:** Artikel können deaktiviert werden ohne sie zu löschen

### Rechnungsstellung (POS)
- **Kassenverkauf:** Erstellung von Rechnungen für Warenverkäufe
- **Positionserfassung:** Mehrere Artikel pro Rechnung
- **Kundenzuordnung:** Mitglied oder Walk-in Kunde
- **Status-Workflow:** Offen → Bezahlt/Storniert
- **Rechnungsnummern:** Format `R-YYYY-XXXXX`

### Stammdaten & Einstellungen
- **Konfigurationsspeicher:** Schlüssel-Wert-Prinzip für alle Einstellungen
- **MwSt-Verwaltung:** Standard- und ermäßigter Satz, aktiver Schlüssel
- **Firmendaten:** Name, Adresse für Rechnungsdruck
- **Systempfade:** Export- und Backup-Verzeichnisse
- **Kategorien:** Gruppierte Darstellung (Finanzen, Programm, Firma)

### Weitere Module
- **Dashboard:** Übersicht über wichtige Kennzahlen
- **Kalender:** Terminübersicht für Vereinsaktivitäten
- **Bemerkungen:** Freitext-Notizen für alle Entitäten

## 🛠 Tech Stack

| Komponente | Technologie | Zweck |
|------------|-------------|-------|
| **Framework** | Flutter 3.x | Cross-Platform UI |
| **State Management** | hooks_riverpod + CodeGen | Reaktiver State |
| **Database** | Drift (SQLite) | Lokale Datenpersistenz |
| **Routing** | go_router | Deklarative Navigation |
| **Data Grids** | pluto_grid | Tabellarische Datenansichten |
| **UI Utilities** | flutter_hooks, gap, intl | Hooks, Layout, Lokalisierung |
| **Data Classes** | freezed + json_serializable | Immutable Models |

### Architektur-Prinzipien

- **Feature-First Struktur:** Code ist nach Features organisiert (`lib/features/*/`), nicht nach Typen
- **Repository Pattern:** Alle Datenbankzugriffe sind in Riverpod-Providern gekapselt
- **Desktop-Optimierung:** UI ist strikt für Maus & Tastatur optimiert (keine Mobile-Patterns)
- **Code-Generierung:** Umfangreiche Nutzung von Build-Runner für typsicheren Code
- **Single Source of Truth:** [`lib/assets/data/structur.md`](lib/assets/data/structur.md) definiert Datenbank-Schema und UI-Konfiguration

## 📊 Datenbank-Schema

### Haupttabellen

| Tabelle | Beschreibung |
|---------|--------------|
| `mitglied` | Mitgliederstammdaten, Vertragsdaten |
| `leistung` | Vertragsarten/Leistungskatalog |
| `beitrag` | Mitgliedsbeiträge mit Status |
| `beitrag_status_verlauf` | Unveränderliche Status-Historie |
| `waren` | Artikelstamm der Warenwirtschaft |
| `rechnung` | Rechnungen für Warenverkäufe |
| `rechnung_position` | Einzelpositionen einer Rechnung |
| `preis` | Preisdefinitionen (Brutto/Netto) |
| `stammdaten` | Konfigurationseinstellungen |
| `bemerkung` | Freitext-Notizen (wiederverwendbar) |

### Relationen

- Mitglied → Leistung (n:1)
- Mitglied → Beitrag (1:n)
- Beitrag → BeitragStatusVerlauf (1:n)
- Rechnung → RechnungPosition (1:n)
- RechnungPosition → Waren (n:1)
- Alle Entitäten → Bemerkung (optional n:1)

## 💻 Entwicklung

### Voraussetzungen

- Flutter SDK (aktueller Stable-Channel)
- Dart SDK
- Unterstützung für Desktop-Builds (Windows/macOS/Linux)

### Code Generation

Dieses Projekt nutzt umfangreiche Code-Generierung. Nach Änderungen an Models, Providern oder Datenbanktabellen muss der Build-Runner ausgeführt werden:

```bash
# Einmalige Generierung
dart run build_runner build -d

# Oder für laufende Entwicklung mit Watch
dart run build_runner watch -d
```

### App starten

```bash
# Für macOS
flutter run -d macos

# Für Windows
flutter run -d windows

# Für Linux
flutter run -d linux
```

## 📐 UI-Komponenten

### AppDataGridV2

Alle tabellarischen Ansichten nutzen die generische `AppDataGridV2<T>` Komponente:

- **Volltextsuche:** Live-Suche über alle sichtbaren Spalten
- **Mehrspaltige Sortierung:** Drag & Drop Sortierung nach Priorität
- **Spaltenfilter:** AND-verknüpfte Filter pro Spalte
- **Doppelklick:** Öffnet Detail-Dialog
- **Enter-Taste:** Barrierefreie Bedienung
- **JSON Export/Import:** Programmatische Datenexporte
- **Zeilenfärbung:** Dynamische Farbgebung basierend auf Daten

### Formularfelder

- **AppTextField:** Standard-Texteingabe mit Validierung
- **AppDatePickerField:** Datumsauswahl mit deutscher Formatierung
- **AppDropdownField:** Einzelauswahl aus fester Liste
- **AppSelectField:** Autocomplete für große dynamische Listen
- **AppEntityAutocomplete:** Entitätsauswahl mit Suchfunktion

## 🎨 Design-System

- **Material 3:** Modernes Design mit anpassbarem Theme
- **Deutsche Lokalisierung:** Datumsformat `dd.MM.yyyy`, Zahlenformat `1.234,56 €`
- **Status-Farben:** Einheitliche Farbcodierung für Beitrags- und Rechnungsstatus
- **Desktop-Layout:** Kompakte Darstellung mit reduziertem Padding

## 📝 Rechnungslegung

Die Rechnungslegung ermöglicht die Massenerstellung von Beiträgen für alle Mitglieder mit gültigem Vertrag.

### Bedienung

1. Menü **"Erstellen"** → **"Rechnungslegung"** auswählen
2. **Jahr** und **Monat** für die Abrechnung wählen
3. Auf **"Speichern"** klicken

### Funktionsweise

**Voraussetzungen:**
- Mitglied muss eine `leistungId` (Vertragsart) zugeordnet haben
- Für den gewählten Zeitraum darf noch kein Beitrag existieren (Duplikat-Prüfung)

**Ablauf:**
- Beiträge werden für alle qualifizierten Mitglieder erstellt
- Eindeutige Rechnungsnummer: `RE-YYYY-XXXXX`
- Kontierungsdatum = aktuelles Datum
- Abrechnungszeitraum = 1. des gewählten Monats
- Initialer Status = **"kontiert"**
- Automatischer History-Eintrag

**Preisfindung:**
- Priorität 1: Individueller Preis des Mitglieds (`preisId`)
- Priorität 2: Standardpreis der zugeordneten Leistung
- Preis wird als Snapshot gespeichert

---

## 📚 Weitere Dokumentation

| Datei | Inhalt |
|-------|--------|
| [`lib/assets/data/structur.md`](lib/assets/data/structur.md) | Vollständiges Datenbank-Schema und UI-Konfiguration |
| [`.agent/rules/projekt_rules.md`](.agent/rules/projekt_rules.md) | Entwicklungsrichtlinien für KI-Assistenten |
| [`AGENTS.md`](AGENTS.md) | Agent-Modi und Workflow-Dokumentation |

---

*Entwickelt mit modernen Flutter Best Practices und Desktop-First Ansatz.*
