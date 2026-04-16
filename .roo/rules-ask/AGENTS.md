# AGENTS.md

This file provides guidance to agents when working in **Ask** mode.

## Ask Mode - Non-Obvious Context

### Architektur-Überblick
- **Framework**: Flutter Desktop (Windows/Linux/macOS)
- **State Management**: Riverpod mit Code-Generation
- **Database**: Drift (SQLite)
- **Data Grids**: Pluto Grid

### Wichtige Dokumentations-Dateien
| Datei | Inhalt |
|-------|--------|
| `lib/assets/data/structur.md` | **Single Source of Truth** - Datenbankschema, Relationen, UI-Konfiguration |
| `lib/core/database/database.dart` | Schema-Version (15), Migrationen |
| `.roo/rules/01-flutter-general.md` | Allgemeine Flutter-Regeln |
| `.roo/rules-code/01-dart-style.md` | Code-Style-Regeln |

### Projekt-Spezifische Konventionen
- **Einrückung**: 2 Leerzeichen (nicht Standard 4)
- **Zeilenlänge**: 100 Zeichen
- **Sprache**: Code auf Englisch, UI auf Deutsch
- **Import-Reihenfolge**: Dart SDK → Flutter Packages → Core → Feature-Local

### Status-Farben (Niemals hardcoden)
- `kontiert` → `#FFF9C4`
- `offen` → `#FFE0B2`
- `bezahlt` → `#C8E6C9`
- `angemahnt` → `#FFCDD2`
- `storniert` → `#EEEEEE`
- `inkasso` → `#F8BBD0`

### Repository-Pattern
- Repositories in `features/<name>/data/`
- Domain-Modelle in `features/<name>/domain/models/`
- UI-Provider in `features/<name>/presentation/providers/`

### Status-Historie
- Jede Status-Änderung bei `beitrag` erfordert Eintrag in `beitrag_status_verlauf`
- Bemerkung ist **Pflichtfeld** bei Status-Änderungen

### Export-Architektur
- `lib/features/export/` = UI + Konfiguration
- `lib/widgets/data_grid_v2/export/` = Wiederverwendbare PDF/CSV-Infrastruktur
