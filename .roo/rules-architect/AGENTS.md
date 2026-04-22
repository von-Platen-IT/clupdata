# AGENTS.md

This file provides guidance to agents when working in **Architect** mode.

## Architect Mode - Non-Obvious Rules

### Single Source of Truth (KRITISCH)
**Datei [`lib/assets/data/structur.md`](lib/assets/data/structur.md:1) ist die zentrale Spezifikation.**
- Jede Schema-Änderung MUSS zuerst hier dokumentiert werden
- Tabellen, Indizes, Relationen, UI-Konfiguration
- Nach Implementierung: Dokumentation synchron halten

### Schema-Versionierung
- Aktuelle Version: **15** in [`lib/core/database/database.dart:46`](lib/core/database/database.dart:46)
- Bei Änderungen: Version erhöhen + Migration definieren
- Migrationen sind **inkrementell** (forward-only)
- Nie destruktive Operationen ohne Daten-Migration

### Datenbank-Design
- Tabellen in `lib/core/database/tables/`
- Jede Tabelle eigene Datei: `{entity}_table.dart`
- Foreign Keys mit `onDelete` definieren
- `PRAGMA foreign_keys = ON` in `beforeOpen`
- WAL-Modus aktiv - für Backups: `await db.checkpoint()`

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
- `@Riverpod(keepAlive: true)` für globale Daten (z.B. [`appDatabaseProvider`](lib/core/providers/database_provider.dart:11))
- `ref.invalidate()` für Neuladen bei nächster Verwendung
- `await ref.refresh()` für sofortiges Neuladen
- Repositories über Konstruktor-Injektion (testbar)

### Status-Historie Pattern
- Jede Status-Änderung erfordert Eintrag in Historientabelle
- Bemerkung ist Pflichtfeld (NOT NULL)
- Historie ist read-only nach Erstellung
- [`BeitraegeRepository.updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) erkennt Status-Änderung automatisch

### Export-Feature Split
- Feature-spezifisch: `lib/features/export/`
- Generisch wiederverwendbar: `lib/widgets/data_grid_v2/export/`

### Sicherheit
- Keine String-Interpolation in SQL
- Drift's Type-Safe API nutzen
- Keine personenbezogenen Daten loggen

### Datenbank-Tabellen (aktuell)
| Tabelle | Zweck |
|---------|-------|
| `bemerkung` | Generische Notizen (FK von allen Entities) |
| `stammdaten` | Key/Value Konfiguration (MwSt, Pfade, etc.) |
| `preis` | Preis-Entity (brutto/netto Berechnung) |
| `leistung` | Services/Mitgliedschaften |
| `mitglied` | Haupt-Entity Mitglieder |
| `waren` | Artikel/Verkaufswaren |
| `beitrag` | Rechnungen/Zahlungen für Leistungen |
| `beitrag_status_verlauf` | Status-History für Beiträge |
| `rechnung` | Rechnungen für Warenverkäufe (POS) |
| `rechnung_position` | Positionen einer Rechnung |

### Relations-Pattern
- `bemerkung_id` als FK in fast allen Tabellen (SET NULL)
- CASCADE bei `beitrag_status_verlauf` und `rechnung_position`
- RESTRICT bei kritischen FKs (beitrag.mitglied_id, beitrag.leistung_id)
