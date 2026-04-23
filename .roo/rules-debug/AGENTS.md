# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Debug Mode - Non-Obvious Rules

- **Dev DB**: `clup_data_dev.sqlite` (project root) | **Prod DB**: `clup_data.sqlite` (next to executable)
- **WAL mode** is active — must call `await db.checkpoint()` before backups for consistent state
- **Schema version** is at [`database.dart:46`](lib/core/database/database.dart:46) — currently **15**
- **Code generation issues** (class not found, import errors): Run `flutter pub run build_runner build -d` then **restart app** — Hot Reload does NOT work for generated code
- **Custom SQL in Drift**: Must use `Variable<T>()` for parameters — never string interpolation
- **Migrations are forward-only** — `migrator.deleteTable()` only safe in development, never in production without data migration
- **`avoid_print` lint** is configured (commented out in analysis_options.yaml but noted) — use `debugPrint` instead
- **Foreign keys** enforced via `PRAGMA foreign_keys = ON` in `beforeOpen` — FK violations cause silent failures if not caught
- **Drift In-Memory DB** for tests: `AppDatabase(NativeDatabase.memory())` — never use real DB in tests
