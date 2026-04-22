# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Non-Obvious Project-Specific Rules

### Critical: Single Source of Truth
**File [`lib/assets/data/structur.md`](lib/assets/data/structur.md:1) MUST be updated BEFORE any database or UI changes.**
- Defines complete schema, indexes, relations, and UI configuration
- Schema version is currently **15** (see [`lib/core/database/database.dart:46`](lib/core/database/database.dart:46))

### Code Generation (MANDATORY)
After changes to `@riverpod`, `@DriftDatabase`, `@freezed`, or `@JsonSerializable`:
```bash
flutter pub run build_runner build -d
```
**Hot Reload does NOT work for generated code** - restart the app after code generation.

### Project-Specific Style (Different from Standard Dart)
| Setting | Value | Standard |
|---------|-------|----------|
| Indentation | 2 spaces | 4 spaces |
| Line Length | 100 chars | 80 chars |
| Trailing Commas | Required on multi-line | Optional |

### Database Conventions
- **Development DB**: `clup_data_dev.sqlite` (project root)
- **Production DB**: `clup_data.sqlite` (next to executable)
- Foreign keys: `PRAGMA foreign_keys = ON` enforced in `beforeOpen`
- Migrations are **incremental** - never delete tables in production without data migration

### Status Colors (MANDATORY - Never Hardcode Hex)
| Status | Hex |
|--------|-----|
| `kontiert` | `#FFF9C4` |
| `offen` | `#FFE0B2` |
| `bezahlt` | `#C8E6C9` |
| `angemahnt` | `#FFCDD2` |
| `storniert` | `#EEEEEE` |
| `inkasso` | `#F8BBD0` |

Source: [`lib/features/beitraege/utils/beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart:1)

### Import Order (Enforced by Project Convention)
```dart
import 'dart:...';              // Dart SDK imports

import 'package:flutter/...';   // Flutter packages
import 'package:hooks_riverpod/...';

import '../../../core/...';      // Core layer
import '../models/...';          // Feature-local imports
```

### Widget Patterns
- `ConsumerWidget` for simple screens
- `HookConsumerWidget` when using `useTextController()`, `useScrollController()`, etc.
- Avoid `StatefulWidget` - use hooks instead
- Dialogs use [`AppEditDialogScaffold`](lib/common_widgets/app_edit_dialog_scaffold.dart:35) from `common_widgets/`
- Delete buttons use [`AppDialogDeleteAction`](lib/common_widgets/app_dialog_delete_action.dart:8) with built-in confirmation

### Repository Pattern
- Repository files: `features/<name>/data/<name>_repository.dart`
- Repository contains ONLY the class and `@riverpod` provider
- Domain models: `features/<name>/domain/models/`
- UI providers: `features/<name>/presentation/providers/`
- Bemerkung operations centralized in [`lib/core/data/bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart:1)

### Status History Requirement
Every status change on `beitrag` MUST create an entry in `beitrag_status_verlauf` with a **mandatory** comment. The [`BeitraegeRepository.updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) method handles this automatically.

### Export Feature Split Architecture
- `lib/features/export/` - Feature-specific UI and config
- `lib/widgets/data_grid_v2/export/` - Reusable export infrastructure (PDF/CSV)

### Testing
```bash
flutter test                    # Run all tests
flutter test test/widget_test.dart  # Run single test
```
Current test coverage is minimal - only template test exists.

### Build Commands
```bash
flutter pub run build_runner build -d   # Code generation (REQUIRED after annotations change)
flutter analyze                          # Static analysis
dart format --output=none --set-exit-if-changed .  # Format check
flutter run -d macos|windows|linux       # Run app (Desktop only)
```

### Security Rules
- **NEVER** use string interpolation in SQL queries
- Always use Drift's type-safe API
- Never log member data (only IDs)
- No `rm -rf`, `DROP TABLE`, or destructive operations

### UI Localization (German)
- Date format: `dd.MM.yyyy`
- Number format: German (1.234,56)
- Currency: `123,45 €` (symbol after amount)
- All UI text in German

### Key Dependencies
- **State Management**: Riverpod (hooks_riverpod ^3.3.1) with code generation
- **Database**: Drift (^2.31.0) SQLite
- **Data Grid**: Pluto Grid (^8.0.0)
- **Routing**: go_router (^17.1.0)
- **PDF**: pdf (^3.10.0) + printing (^5.11.0)
- **Freezed**: freezed (^3.2.5) for immutable state

### Routes (StatefulShellRoute)
| Path | Screen |
|------|--------|
| `/` | DashboardScreen |
| `/members` | MembersScreen |
| `/leistungen` | LeistungenScreen |
| `/beitraege` | BeitraegeScreen |
| `/waren` | WarenScreen |
| `/rechnungen` | RechnungenScreen |
| `/pos` | PosScreen |
| `/calendar` | CalendarScreen |
| `/master-data` | StammdatenScreen |
