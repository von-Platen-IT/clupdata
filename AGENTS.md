# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Critical Project Rules

- **SSOT**: [`lib/assets/data/structur.md`](lib/assets/data/structur.md) MUST be updated BEFORE any database or UI change. Schema version is **15** ([`database.dart:46`](lib/core/database/database.dart:46)).
- **Code generation is MANDATORY** after changing `@riverpod`, `@DriftDatabase`, `@freezed`, or `@JsonSerializable`:
  ```bash
  flutter pub run build_runner build -d
  ```
  Hot Reload does NOT work for generated code — restart the app.

## Non-Obvious Conventions

- **2-space indentation**, **100-char line length**, **trailing commas on multi-line** (differs from Dart default 4-space/80-char)
- **Never use `StatefulWidget`** — use `HookConsumerWidget` with `flutter_hooks` instead
- **`gap` package** for spacing instead of `SizedBox(height: ...)`
- **Status colors**: NEVER hardcode hex — use [`beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart)
- **Bemerkung operations** are centralized in [`bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart), not per-feature
- **Status history** on `beitrag` is auto-detected by [`updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) — comment is mandatory (NOT NULL)
- **Rechnungsnummer formats differ**: Beiträge = `RE-YYYY-XXXXX`, Waren = `R-YYYY-XXXXX`
- **CSV export** uses UTF-8 with BOM for Excel compatibility
- **Drift table class names** are German-pluralized: `Mitglieds`, `Beitraege`, `Rechnungen`, `RechnungPositionen`

## Database Gotchas

- Dev DB: `clup_data_dev.sqlite` (project root) | Prod DB: `clup_data.sqlite` (next to executable)
- WAL mode active — call `await db.checkpoint()` before backups
- Foreign keys enforced via `PRAGMA foreign_keys = ON` in `beforeOpen`
- Migrations are **forward-only** — never `deleteTable` in production without data migration
- Each table in its own file: `lib/core/database/tables/{entity}_table.dart`

## Build/Lint/Test

```bash
flutter pub run build_runner build -d          # Code generation (REQUIRED after annotation changes)
flutter analyze                                 # Static analysis
dart format --output=none --set-exit-if-changed .  # Format check
flutter test test/some_test.dart                # Run single test
flutter test --coverage                         # Run all tests with coverage
```

## Export Architecture Split

- Feature-specific UI/config: `lib/features/export/`
- Reusable PDF/CSV infrastructure: `lib/widgets/data_grid_v2/export/`
