# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Non-Obvious Project-Specific Rules

### Critical: Single Source of Truth
**File `lib/assets/data/structur.md` MUST be updated BEFORE any database or UI changes.**
- This file defines the complete schema, indexes, relations, and UI configuration
- All table definitions, migrations, and UI screens must stay in sync with structur.md
- Schema version is currently **15** (see `lib/core/database/database.dart`)

### Code Generation Requirements
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

Source: `lib/features/beitraege/utils/beitrag_status_colors.dart`

### Import Order (Enforced by Project Convention)
```dart
import 'dart:...';              // Dart SDK imports

import 'package:flutter/...';   // Flutter packages
import 'package:hooks_riverpod/...';

import '../../../core/...';      // Core layer
import '../models/...';          // Feature-local imports
```

### Widget Patterns Specific to This Project
- Use `ConsumerWidget` for simple screens
- Use `HookConsumerWidget` when using `useTextController()`, `useScrollController()`, etc.
- Avoid `StatefulWidget` - use hooks instead
- Dialogs use `AppEditDialogScaffold` from `common_widgets/`

### Repository Pattern Rules
- Repository files go in `features/<name>/data/<name>_repository.dart`
- Repository contains ONLY the class and `@riverpod` provider
- Domain models go in `features/<name>/domain/models/`
- UI providers go in `features/<name>/presentation/providers/`

### Status History Requirement
Every status change on `beitrag` MUST create an entry in `beitrag_status_verlauf` with a **mandatory** comment explaining the change.

### Export Feature Split Architecture
- `lib/features/export/` - Feature-specific UI and config
- `lib/widgets/data_grid_v2/export/` - Reusable export infrastructure (PDF/CSV)

### Testing
```bash
# Run all tests
flutter test

# Run single test
flutter test test/widget_test.dart
```
Current test coverage is minimal - only template test exists.

### Build Commands
```bash
# Code generation (REQUIRED after annotations change)
flutter pub run build_runner build -d

# Static analysis
flutter analyze

# Format check
dart format --output=none --set-exit-if-changed .

# Run app (Desktop only)
flutter run -d macos|windows|linux
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
