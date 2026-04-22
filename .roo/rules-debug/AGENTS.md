# AGENTS.md

This file provides guidance to agents when working in **Debug** mode.

## Debug Mode - Non-Obvious Rules

### Datenbank-Debugging
- **Development DB**: `clup_data_dev.sqlite` im Projekt-Root
- **Production DB**: `clup_data.sqlite` neben der Executable
- **Foreign Keys**: `PRAGMA foreign_keys = ON` automatisch in `beforeOpen`
- Schema-Version prüfen in [`lib/core/database/database.dart:46`](lib/core/database/database.dart:46) (aktuell: 15)
- WAL-Modus aktiv - für konsistente Backups: `await db.checkpoint()` aufrufen

### Code-Generierung-Probleme
- **Symptom**: Klassen nicht gefunden / Import-Fehler
- **Lösung**: `flutter pub run build_runner build -d` ausführen
- **Wichtig**: Hot Reload funktioniert NICHT für generierten Code - App neu starten!

### Riverpod Debugging
- `ref.invalidate(provider)` löscht Cache, lädt aber nicht sofort neu
- `await ref.refresh(provider.future)` lädt sofort neu
- Provider-Abhängigkeiten prüfen mit `ref.watch()` vs `ref.read()`
- `keepAlive: true` Provider werden nicht bei Dispose geschlossen (z.B. [`appDatabaseProvider`](lib/core/providers/database_provider.dart:11))

### Drift/Fehler
- SQL-Injection prüfen: NIE String-Interpolation verwenden
- Type-Safe API nutzen: `where((m) => m.id.equals(id))`
- Migrationen: `schemaVersion` in `database.dart` muss erhöht werden
- Custom SQL Queries: `customSelect()` mit `Variable<T>()` für Parameter

### Migration Debugging
- Migrationen sind **inkrementell** (forward-only)
- Bei Problemen: `from` und `to` Versionen in [`database.dart:58`](lib/core/database/database.dart:58) prüfen
- `migrator.deleteTable()` nur in Development, nie in Production

### Desktop-Spezifisch
- UI für Maus+Tastatur optimiert
- `VisualDensity.compact` wird verwendet
- Keine Mobile-Patterns (Swipe, etc.)
- `window_manager` Package für Fenster-Steuerung

### Log-Ausgabe
- Keine personenbezogenen Daten loggen (nur IDs)
- `avoid_print` Lint-Regel aktiv
- `debugPrint` für strukturierte Logs verwenden

### Pluto Grid Debugging
- Data Grid verwendet `pluto_grid` Package
- Custom Controller: `lib/widgets/data_grid_v2/data_grid_controller.dart`
- Filter/Sort Dialoge: `lib/widgets/data_grid_v2/filter_settings_dialog.dart`
