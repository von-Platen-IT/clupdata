# AGENTS.md

This file provides guidance to agents when working in **Architect** mode.

## Architect Mode - Non-Obvious Rules

### Single Source of Truth (KRITISCH)
**Datei `lib/assets/data/structur.md` ist die zentrale Spezifikation.**
- Jede Schema-Änderung MUSS zuerst hier dokumentiert werden
- Tabellen, Indizes, Relationen, UI-Konfiguration
- Nach Implementierung: Dokumentation synchron halten

### Schema-Versionierung
- Aktuelle Version: **15** in `lib/core/database/database.dart`
- Bei Änderungen: Version erhöhen + Migration definieren
- Migrationen sind **inkrementell** (forward-only)
- Nie destruktive Operationen ohne Daten-Migration

### Datenbank-Design
- Tabellen in `lib/core/database/tables/`
- Jede Tabelle eigene Datei: `{entity}_table.dart`
- Foreign Keys mit `onDelete` definieren
- `PRAGMA foreign_keys = ON` in `beforeOpen`

### Feature-Modul-Struktur
```
features/<name>/
├── data/<name>_repository.dart       # Repository + Provider
├── domain/models/                    # Domain-Modelle
├── presentation/
│   ├── providers/                    # UI-State Provider
│   ├── dialogs/                      # Edit/Create Dialoge
│   └── widgets/                      # Feature-Widgets
└── <name>_screen.dart
```

### Layer-Architektur
1. **Data Layer**: Repositories kapseln DB-Zugriff
2. **Domain Layer**: Models, Enums (keine Flutter-Deps)
3. **Presentation Layer**: Widgets + Provider

### Riverpod Architektur
- `@riverpod` für Repository-Provider
- `AsyncNotifier` für komplexe States
- `StreamProvider` für Live-Daten
- `autoDispose` für speicherintensive Provider
- `keepAlive` für globale Daten

### Status-Historie Pattern
- Jede Status-Änderung erfordert Eintrag in Historientabelle
- Bemerkung ist Pflichtfeld
- Historie ist read-only nach Erstellung

### Export-Feature Split
- Feature-spezifisch: `lib/features/export/`
- Generisch wiederverwendbar: `lib/widgets/data_grid_v2/export/`

### Sicherheit
- Keine String-Interpolation in SQL
- Drift's Type-Safe API nutzen
- Keine personenbezogenen Daten loggen
