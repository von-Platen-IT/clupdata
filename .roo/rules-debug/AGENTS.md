# AGENTS.md

This file provides guidance to agents when working in **Debug** mode.

## Debug Mode - Non-Obvious Rules

### Datenbank-Debugging
- **Development DB**: `clup_data_dev.sqlite` im Projekt-Root
- **Foreign Keys**: `PRAGMA foreign_keys = ON` automatisch in `beforeOpen`
- Schema-Version prüfen in `lib/core/database/database.dart` (aktuell: 15)

### Code-Generierung-Probleme
- **Symptom**: Klassen nicht gefunden / Import-Fehler
- **Lösung**: `flutter pub run build_runner build -d` ausführen
- **Wichtig**: Hot Reload funktioniert NICHT für generierten Code - App neu starten!

### Riverpod Debugging
- `ref.invalidate(provider)` löscht Cache, lädt aber nicht sofort neu
- `await ref.refresh(provider.future)` lädt sofort neu
- Provider-Abhängigkeiten prüfen mit `ref.watch()` vs `ref.read()`

### Drift/Fehler
- SQL-Injection prüfen: NIE String-Interpolation verwenden
- Type-Safe API nutzen: `where((m) => m.id.equals(id))`
- Migrationen: `schemaVersion` in `database.dart` muss erhöht werden

### Desktop-Spezifisch
- UI für Maus+Tastatur optimiert
- `VisualDensity.compact` wird verwendet
- Keine Mobile-Patterns (Swipe, etc.)

### Log-Ausgabe
- Keine personenbezogenen Daten loggen (nur IDs)
- `avoid_print` Lint-Regel aktiv
