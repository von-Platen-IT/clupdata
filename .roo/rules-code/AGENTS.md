# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Code Mode - Non-Obvious Rules

- **Never `StatefulWidget`** — always `HookConsumerWidget` + `flutter_hooks` (`useTextEditingController()`, `useMemoized()`, etc.)
- **`gap` package** for spacing — never `SizedBox(height: ...)` or `SizedBox(width: ...)`
- **Status colors**: NEVER hardcode hex — always use [`beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart)
- **Bemerkung operations** are centralized in [`bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart) — not per-feature
- **Status history** on `beitrag` is auto-detected by [`updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) — comment is mandatory (NOT NULL), never call `_addStatusEintrag()` directly
- **Rechnungsnummer formats differ**: Beiträge = `RE-YYYY-XXXXX`, Waren = `R-YYYY-XXXXX`
- **Drift table class names** use German pluralization (`Mitglieds`, `Beitraege`, `Rechnungen`, `RechnungPositionen`) but **SQLite table names** use singular per structur.md (`mitglied`, `beitrag`, `rechnung`, `rechnung_position`) via `tableName` override. Never change class names — only override `tableName` if needed.
- **CSV export** uses UTF-8 with BOM for Excel compatibility
- **Dialogs**: Use [`AppEditDialogScaffold`](lib/common_widgets/app_edit_dialog_scaffold.dart) — has built-in ESC/Enter shortcuts; Enter skips save when multi-line textfield or dropdown is focused
- **Delete buttons**: Use [`AppDialogDeleteAction`](lib/common_widgets/app_dialog_delete_action.dart) — has built-in confirmation
- **2-space indent**, **100-char line length**, **trailing commas on multi-line** (differs from Dart defaults)
- **`@Riverpod(keepAlive: true)`** only for global singletons like [`appDatabaseProvider`](lib/core/providers/database_provider.dart:11) — all others auto-dispose
- **Row mappings in DataGrid**: NEVER compute in `build()` — use `useMemoized` or a provider
- **Computed fields**: Calculate in providers, never in DataGrid or Dialog widgets
- **Form fields**: Use [`app_text_field.dart`](lib/common_widgets/forms/app_text_field.dart), [`app_date_picker_field.dart`](lib/common_widgets/forms/app_date_picker_field.dart), [`app_dropdown_field.dart`](lib/common_widgets/forms/app_dropdown_field.dart) — never raw Material widgets
