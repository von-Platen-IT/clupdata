# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- **SSOT**: [`structur.md`](lib/assets/data/structur.md) MUST be updated BEFORE any database or UI change. Schema version is **16** ([`database.dart:46`](lib/core/database/database.dart:46)).
- **Code generation is MANDATORY** after changing `@riverpod`, `@DriftDatabase`, `@freezed`, or `@JsonSerializable`: `flutter pub run build_runner build -d` — Hot Reload does NOT work for generated code, restart the app.
- **Never `StatefulWidget`** — always `HookConsumerWidget` + `flutter_hooks` (`useTextEditingController()`, `useMemoized()`, etc.)
- **`gap` package** for spacing — never `SizedBox(height: ...)` or `SizedBox(width: ...)`
- **2-space indent**, **100-char line length**, **trailing commas on multi-line** (differs from Dart defaults of 4-space/80-char)
- **Status colors**: NEVER hardcode hex — use [`beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart)
- **Bemerkung operations** are centralized in [`bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart), not per-feature
- **Status history** on `beitrag` is auto-detected by [`updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) — comment is mandatory (NOT NULL), never call `_addStatusEintrag()` directly
- **Rechnungsnummer formats differ**: Beiträge = `RE-YYYY-XXXXX`, Waren = `R-YYYY-XXXXX`
- **Drift table class names** use German pluralization (`Mitglieds`, `Beitraege`, `Rechnungen`, `RechnungPositionen`) but **SQLite table names** use singular (`mitglied`, `beitrag`, `rechnung`, `rechnung_position`) via `tableName` override — never change class names
- **CSV export** uses UTF-8 with BOM for Excel compatibility
- **Dev DB**: `clup_data_dev.sqlite` (project root) | **Prod DB**: `clup_data.sqlite` (next to executable)
- **WAL mode** active — call `await db.checkpoint()` before backups
- **Migrations are forward-only** — never `deleteTable` in production without data migration
- **FK cascade rules differ**: `beitrag_status_verlauf`/`rechnung_position` use CASCADE; `beitrag.mitglied_id` uses RESTRICT
- **Export architecture split**: Feature UI in `lib/features/export/`, reusable PDF/CSV infrastructure in `lib/widgets/data_grid_v2/export/`

```bash
flutter pub run build_runner build -d          # Code generation (REQUIRED after annotation changes)
flutter analyze                                 # Static analysis
dart format --output=none --set-exit-if-changed .  # Format check
flutter test test/some_test.dart                # Run single test
flutter test --coverage                         # Run all tests with coverage
```
