# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Architect Mode - Non-Obvious Rules

- **[`lib/assets/data/structur.md`](lib/assets/data/structur.md)** is SSOT — every schema or UI change MUST be documented here first, then implemented
- **Schema version** is at [`database.dart:46`](lib/core/database/database.dart:46) — increment on every table change and add corresponding migration in `onUpgrade`
- **Migrations are forward-only** — never `deleteTable` in production without data migration; v5 reset is a one-time exception
- **Drift table class names** are German-pluralized: `Mitglieds`, `Beitraege`, `Rechnungen`, `RechnungPositionen` — not English singular/plural
- **`bemerkung_id`** FK exists in almost all tables with `SET NULL` on delete — central note system
- **FK cascade rules differ**: `beitrag_status_verlauf` and `rechnung_position` use CASCADE; critical FKs like `beitrag.mitglied_id` use RESTRICT
- **Status history pattern**: [`updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) auto-detects status changes — never implement manual status logging
- **Export architecture split**: Feature UI in `lib/features/export/`, reusable infrastructure in `lib/widgets/data_grid_v2/export/` — never mix concerns
- **`@Riverpod(keepAlive: true)`** only for global singletons like [`appDatabaseProvider`](lib/core/providers/database_provider.dart:11) — all other providers auto-dispose
- **Repositories** receive `AppDatabase` via constructor injection (for testability), exposed via `@riverpod` provider function
- **Plans go in `/plans`**, ADRs in `/plans/adr/ADR-<nummer>-<titel>.md`, feature plans in `/plans/features/<name>.md`
