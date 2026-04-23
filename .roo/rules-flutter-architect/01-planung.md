# Architekturregeln – Flutter Architect Mode

## Pflichtregeln
- Alle Planungsdokumente werden im Ordner `/plans` gespeichert
- Architekturentscheidungen werden als ADR (Architecture Decision Record) dokumentiert
  - Format: `/plans/adr/ADR-<nummer>-<titel>.md`
- Neue Features werden zuerst als Plan in `/plans/features/<feature-name>.md` beschrieben
- Datenbankschemas werden in `/plans/schema/` abgelegt

## Single Source of Truth (SSOT)
- **[`lib/assets/data/structur.md`](lib/assets/data/structur.md)** ist die zentrale Spezifikation für:
  - Datenbank-Schema (Tabellen, Felder, Indizes)
  - Relationen zwischen Entities
  - UI-Konfiguration (Screens, Dialoge, Data Grid Spalten)
  - Status-Farben und Business-Regeln
- **[MUST]** Jede Änderung an Datenbank oder UI MUSS zuerst in `structur.md` dokumentiert werden
- Schema-Version ist aktuell **15** (siehe [`lib/core/database/database.dart`](lib/core/database/database.dart))

## Flutter-Architekturprinzipien

### Feature-First-Ordnerstruktur
```
lib/
├── main.dart                    # Entry Point
├── core/                        # Shared Kernel
│   ├── database/               # Drift Database
│   │   ├── database.dart       # Database Setup
│   │   ├── tables/            # Table Definitions
│   │   └── schema_versions.dart
│   ├── providers/             # Global Riverpod Providers
│   ├── router/                # GoRouter Configuration
│   └── theme/                 # AppTheme & Styling
├── common_widgets/            # Shared UI Components
│   ├── forms/                 # Form Field Widgets
│   └── ...                    # Dialogs, Shell, etc.
└── features/                  # Feature Modules
    ├── beitraege/             # Beitragsverwaltung
    │   ├── data/              # Repositories
    │   ├── domain/models/     # Domain Models
    │   ├── presentation/      # UI Layer
    │   │   ├── providers/     # Riverpod Providers
    │   │   ├── dialogs/       # Edit/New Dialogs
    │   │   └── widgets/       # Feature Widgets
    │   ├── services/          # Business Services
    │   └── beitraege_screen.dart
    ├── leistungen/            # Leistungskatalog
    ├── waren/                 # Warenwirtschaft
    ├── rechnungen/            # Rechnungsstellung
    ├── stammdaten/            # Einstellungen
    ├── export/                # Export-Feature
    ├── dashboard/             # Dashboard
    └── pos/                   # Point of Sale
```

### Layer-Architektur
1. **Data Layer**: Repositories kapseln Datenbankzugriff (Drift)
2. **Domain Layer**: Models mit Business-Logik (keine Flutter-Dependencies)
3. **Presentation Layer**: Widgets und Riverpod Providers

### Dependency Injection
- Riverpod mit Code-Generation (`@riverpod`) für alle Provider
- `@Riverpod(keepAlive: true)` für globale Daten (z.B. `appDatabaseProvider`)
- Repositories erhalten `AppDatabase` über Konstruktor-Injection

### Datenbank-Architektur (Drift)
- Tabellen in `lib/core/database/tables/` – jede Tabelle eigene Datei: `{entity}_table.dart`
- Foreign Keys: `PRAGMA foreign_keys = ON` enforced in `beforeOpen`
- Migrations sind **inkrementell** – niemals Tabellen in Produktion löschen ohne Datenmigration
- Development DB: `clup_data_dev.sqlite` (Projekt-Root)
- Production DB: `clup_data.sqlite` (neben Executable)

### Export-Architektur Split
- Feature-spezifisch: `lib/features/export/`
- Generisch wiederverwendbar: `lib/widgets/data_grid_v2/export/`

## Mermaid-Diagramme
- Verwende `classDiagram` für Klassenbeziehungen
- Verwende `flowchart TD` für Datenflüsse
- Verwende `sequenceDiagram` für API-Interaktionen

## Routes (StatefulShellRoute)
| Path | Screen |
|------|--------|
| `/` | DashboardScreen |
| `/members` | MembersScreen |
| `/leistungen` | LeistungenScreen |
| `/beitraege` | BeitraegeScreen |
| `/waren` | WarenScreen |
| `/rechnungen` | RechnungenScreen |
| `/pos` | PosScreen |
| `/calendar` | CalendarScreen |
| `/master-data` | StammdatenScreen |
