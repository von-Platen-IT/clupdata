# AGENTS.md

This file provides guidance to agents when working in **Ask** mode.

## Ask Mode - Non-Obvious Context

### Architektur-Überblick
- **Framework**: Flutter Desktop (Windows/Linux/macOS)
- **State Management**: Riverpod mit Code-Generation (hooks_riverpod ^3.3.1)
- **Database**: Drift (SQLite) mit LazyDatabase
- **Data Grids**: Pluto Grid (^8.0.0)
- **Routing**: go_router mit StatefulShellRoute

### Wichtige Dokumentations-Dateien
| Datei | Inhalt |
|-------|--------|
| [`lib/assets/data/structur.md`](lib/assets/data/structur.md:1) | **Single Source of Truth** - Datenbankschema, Relationen, UI-Konfiguration |
| [`lib/core/database/database.dart`](lib/core/database/database.dart:1) | Schema-Version (15), Migrationen |
| `.roo/rules/01-flutter-general.md` | Allgemeine Flutter-Regeln |
| `.roo/rules-code/01-dart-style.md` | Code-Style-Regeln |

### Projekt-Spezifische Konventionen
- **Einrückung**: 2 Leerzeichen (nicht Standard 4)
- **Zeilenlänge**: 100 Zeichen
- **Sprache**: Code auf Englisch, UI auf Deutsch
- **Import-Reihenfolge**: Dart SDK → Flutter Packages → Core → Feature-Local

### Status-Farben (Niemals hardcoden)
- Zentrale Quelle: [`lib/features/beitraege/utils/beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart:1)
- `kontiert` → `#FFF9C4`, `offen` → `#FFE0B2`, `bezahlt` → `#C8E6C9`
- `angemahnt` → `#FFCDD2`, `storniert` → `#EEEEEE`, `inkasso` → `#F8BBD0`

### Repository-Pattern
- Repositories in `features/<name>/data/`
- Domain-Modelle in `features/<name>/domain/models/`
- UI-Provider in `features/<name>/presentation/providers/`
- **Bemerkung-Operationen zentralisiert** in [`lib/core/data/bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart:1)

### Status-Historie
- Jede Status-Änderung bei `beitrag` erfordert Eintrag in `beitrag_status_verlauf`
- Bemerkung ist **Pflichtfeld** bei Status-Änderungen
- [`BeitraegeRepository.updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) erkennt Status-Änderung automatisch

### Export-Architektur
- `lib/features/export/` = UI + Konfiguration
- `lib/widgets/data_grid_v2/export/` = Wiederverwendbare PDF/CSV-Infrastruktur

### Widget-Patterns
- Dialoge: [`AppEditDialogScaffold`](lib/common_widgets/app_edit_dialog_scaffold.dart:35) mit ESC/Enter Shortcuts
- Löschen: [`AppDialogDeleteAction`](lib/common_widgets/app_dialog_delete_action.dart:8) mit built-in confirmation
- `ConsumerWidget` für einfache Fälle, `HookConsumerWidget` für Controller

### Datenbank-Details
- **Development DB**: `clup_data_dev.sqlite` (Projekt-Root)
- **Production DB**: `clup_data.sqlite` (neben Executable)
- WAL-Modus aktiv - Backups erfordern `checkpoint()`
- Foreign Keys: `PRAGMA foreign_keys = ON` in `beforeOpen`

### Rechnungen-Nummern
- Beiträge: `RE-YYYY-XXXXX` (Jahr + 5-stellige Nummer)
- Waren-Rechnungen: `R-YYYY-XXXXX`
- Automatische Generierung mit Eindeutigkeitsprüfung
