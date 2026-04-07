# Database Code Generation Fix Plan

## Problem Analysis

The Flutter application is experiencing **compilation errors** due to missing generated code files. The errors indicate that:

1. **No `.g.dart` files exist** - Code generation has not been run
2. **Database methods are undefined** - The Drift ORM generated code is missing
3. **Provider references are undefined** - Riverpod generated providers don't exist
4. **Type definitions are missing** - Generated data classes and companions are unavailable

## Root Cause

The project uses **code generation** for two main purposes:

### 1. Drift Database ORM (`drift_dev`)
- Generates `database.g.dart` from [`database.dart`](lib/core/database/database.dart:1)
- Creates table accessors (e.g., `_db.rechnungen`, `_db.bemerkung`)
- Generates data classes (e.g., `Rechnung`, `RechnungPosition`, `Mitglied`)
- Creates companion classes for inserts/updates (e.g., `RechnungenCompanion`, `BemerkungCompanion`)
- Provides query methods (`select`, `update`, `delete`, `insert`, `transaction`)

### 2. Riverpod Providers (`riverpod_generator`)
- Generates `*.g.dart` files for all files with `@riverpod` annotations
- Creates provider instances (e.g., `appDatabaseProvider`, `rechnungenRepositoryProvider`)
- Enables dependency injection throughout the app

### 3. JSON Serialization (`json_serializable`)
- Generates `fromJson` and `toJson` methods for model classes
- Used in [`member_row_data.dart`](lib/features/members/models/member_row_data.dart:1) and [`leistung_row_data.dart`](lib/features/leistungen/models/leistung_row_data.dart:1)

## Error Categories

### Category 1: Missing Drift Generated Code
**Affected Files:** All repository files accessing database
**Symptoms:**
- `The method 'select' isn't defined for the type 'AppDatabase'`
- `The getter 'rechnungen' isn't defined for the type 'AppDatabase'`
- `'RechnungenCompanion' isn't a type`
- `The method 'transaction' isn't defined`

**Examples:**
```dart
// In rechnungen_repository.dart:196
await _db.transaction(() async { ... }  // ❌ transaction not defined

// In rechnungen_repository.dart:198
final positionsQuery = _db.select(_db.rechnungPositionen)  // ❌ select not defined, rechnungPositionen not defined
```

### Category 2: Missing Riverpod Providers
**Affected Files:** All files using `ref.watch()` or `ref.read()`
**Symptoms:**
- `Undefined name 'appDatabaseProvider'`
- `Undefined name 'rechnungenRepositoryProvider'`
- `Undefined name 'membersRepositoryProvider'`

**Examples:**
```dart
// In rechnungen_repository.dart:395
return RechnungenRepository(ref.watch(appDatabaseProvider));  // ❌ appDatabaseProvider undefined

// In neue_rechnung_dialog.dart:103
final repo = ref.read(rechnungenRepositoryProvider);  // ❌ rechnungenRepositoryProvider undefined
```

### Category 3: Missing JSON Serialization
**Affected Files:** Model classes with `@JsonSerializable`
**Symptoms:**
- `Method not found: '_$MemberRowDataFromJson'`
- `Method not found: '_$LeistungRowDataFromJson'`

**Examples:**
```dart
// In member_row_data.dart:28
_$MemberRowDataFromJson(json);  // ❌ Generated function missing
```

### Category 4: Notifier State Access
**Affected File:** [`active_data_grid_provider.dart`](lib/core/providers/active_data_grid_provider.dart:1)
**Symptoms:**
- `The setter 'state' isn't defined for the type 'ActiveDataGridController'`

**Root Cause:** The class extends `_$ActiveDataGridController` (generated), but the generated code doesn't exist yet.

## Files Requiring Generated Code

### Critical Files (Must be generated first):
1. **`lib/core/database/database.g.dart`** - Core database functionality
   - Source: [`lib/core/database/database.dart`](lib/core/database/database.dart:1)
   - Generates: Table accessors, data classes, companions, query methods

2. **`lib/core/providers/database_provider.g.dart`** - Database provider
   - Source: [`lib/core/providers/database_provider.dart`](lib/core/providers/database_provider.dart:1)
   - Generates: `appDatabaseProvider`

### Repository Providers (Depend on database.g.dart):
3. [`lib/features/rechnungen/data/rechnungen_repository.g.dart`](lib/features/rechnungen/data/rechnungen_repository.dart:1)
4. [`lib/features/members/data/members_repository.g.dart`](lib/features/members/data/members_repository.dart:1)
5. [`lib/features/leistungen/data/leistungen_repository.g.dart`](lib/features/leistungen/data/leistungen_repository.dart:1)
6. [`lib/features/leistungen/data/preise_repository.g.dart`](lib/features/leistungen/data/preise_repository.dart:1)
7. [`lib/features/waren/data/waren_repository.g.dart`](lib/features/waren/data/waren_repository.dart:1)
8. [`lib/features/stammdaten/data/stammdaten_repository.g.dart`](lib/features/stammdaten/data/stammdaten_repository.dart:1)
9. [`lib/features/beitraege/providers/beitraege_repository.g.dart`](lib/features/beitraege/providers/beitraege_repository.dart:1)

### UI Providers (Depend on repository providers):
10. [`lib/features/leistungen/presentation/providers/leistungen_list_provider.g.dart`](lib/features/leistungen/presentation/providers/leistungen_list_provider.dart:1)
11. [`lib/features/waren/presentation/providers/waren_list_provider.g.dart`](lib/features/waren/presentation/providers/waren_list_provider.dart:1)
12. [`lib/features/stammdaten/presentation/providers/stammdaten_list_provider.g.dart`](lib/features/stammdaten/presentation/providers/stammdaten_list_provider.dart:1)
13. [`lib/features/members/presentation/providers/members_list_provider.g.dart`](lib/features/members/presentation/providers/members_list_provider.dart:1)
14. [`lib/features/members/presentation/providers/selected_member_provider.g.dart`](lib/features/members/presentation/providers/selected_member_provider.dart:1)

### Other Providers:
15. [`lib/core/providers/active_data_grid_provider.g.dart`](lib/core/providers/active_data_grid_provider.dart:1)
16. [`lib/core/providers/export_context_provider.g.dart`](lib/core/providers/export_context_provider.dart:1)

### JSON Serialization:
17. [`lib/features/members/models/member_row_data.g.dart`](lib/features/members/models/member_row_data.dart:1)
18. [`lib/features/leistungen/models/leistung_row_data.g.dart`](lib/features/leistungen/models/leistung_row_data.dart:1)

## Solution: Run Code Generation

### Step 1: Clean Previous Build Artifacts
```bash
cd clupdata
flutter clean
flutter pub get
```

**Purpose:** Remove any corrupted or partial build artifacts and ensure all dependencies are properly installed.

### Step 2: Run Build Runner
```bash
dart run build_runner build --delete-conflicting-outputs
```

**What this does:**
- Scans all Dart files for code generation annotations
- Generates all `.g.dart` files
- `--delete-conflicting-outputs` flag removes any existing generated files that conflict

**Expected Output:**
- Should generate ~18-20 `.g.dart` files
- Process may take 30-60 seconds
- Will show progress for each file generated

### Step 3: Verify Generated Files
```bash
find lib -name "*.g.dart" | wc -l
```

**Expected:** Should show 18+ files

### Step 4: Rebuild Application
```bash
flutter build linux
# or
flutter run
```

## Alternative: Watch Mode (For Development)

For active development, use watch mode to automatically regenerate code on file changes:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

**Benefits:**
- Automatically regenerates code when source files change
- Keeps generated code in sync during development
- Runs in background

## Verification Checklist

After running code generation, verify:

- [ ] `lib/core/database/database.g.dart` exists and contains `_$AppDatabase` class
- [ ] `lib/core/providers/database_provider.g.dart` exists and exports `appDatabaseProvider`
- [ ] All repository `.g.dart` files exist (9 files)
- [ ] All provider `.g.dart` files exist (6 files)
- [ ] JSON serialization `.g.dart` files exist (2 files)
- [ ] `flutter analyze` shows no errors
- [ ] `flutter build linux` completes successfully

## Common Issues and Solutions

### Issue 1: "Conflicting outputs" Error
**Solution:** Use `--delete-conflicting-outputs` flag

### Issue 2: Build Runner Hangs
**Solution:**
```bash
# Kill any existing build_runner processes
pkill -f build_runner
# Clean and retry
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Issue 3: "Part file doesn't exist" Errors
**Cause:** Generated files haven't been created yet
**Solution:** This is expected before running build_runner; ignore these errors until generation completes

### Issue 4: Linker Error (ld.lld not found)
**Error:** `Failed to find any of [ld.lld, ld] in LocalDirectory: '/usr/lib/llvm-18/bin'`
**Cause:** Missing or misconfigured LLVM linker for Linux builds
**Solution:**
```bash
# Install required build tools
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Or use system linker
export PATH="/usr/bin:$PATH"
flutter build linux
```

## Database Schema Information

Current schema version: **15** (defined in [`database.dart:43`](lib/core/database/database.dart:43))

### Tables Defined:
1. **Bemerkung** - Generic notes/remarks
2. **Stammdaten** - Master data/settings
3. **Preis** - Pricing information
4. **Leistung** - Services/memberships
5. **Mitglieds** - Members
6. **Waren** - Products/goods
7. **Beitraege** - Membership fees/contributions
8. **BeitragStatusVerlauf** - Fee status history
9. **Rechnungen** - Invoices (added in v14)
10. **RechnungPositionen** - Invoice line items (added in v14)

### Recent Schema Changes:
- **v14:** Added Rechnungen and RechnungPositionen tables
- **v15:** Added `abrechnungsZeitraum` column to Beitraege table

## Impact Assessment

### High Priority (Blocking all functionality):
- Database access completely broken
- No repository methods work
- Application cannot start properly

### Medium Priority (Feature-specific):
- Invoice management completely non-functional
- Member management affected
- Product/service management affected

### Low Priority (UI/Export):
- Data grid export functionality affected
- Some UI components may not render

## Recommended Action Plan

### Immediate Actions:
1. ✅ Run `flutter clean && flutter pub get`
2. ✅ Run `dart run build_runner build --delete-conflicting-outputs`
3. ✅ Verify all `.g.dart` files are generated
4. ✅ Run `flutter analyze` to check for remaining issues
5. ✅ Test build with `flutter build linux` or `flutter run`

### Follow-up Actions:
1. Add build_runner to CI/CD pipeline if not already present
2. Document code generation requirements in README
3. Consider adding pre-commit hooks to ensure generated code is up-to-date
4. Add `.g.dart` files to `.gitignore` (best practice) or commit them (for easier deployment)

### Development Workflow:
1. Use `dart run build_runner watch` during active development
2. Run `dart run build_runner build` before committing changes
3. Ensure all team members understand code generation requirements

## Technical Details

### Build Runner Configuration
The project uses these build dependencies (from [`pubspec.yaml`](pubspec.yaml:1)):
```yaml
dev_dependencies:
  build_runner: ^2.12.2      # Code generation orchestrator
  drift_dev: ^2.31.0         # Drift ORM code generator
  riverpod_generator: ^4.0.2 # Riverpod provider generator
  freezed: ^3.2.5            # Immutable class generator
  json_serializable: ^6.13.0 # JSON serialization generator
```

### Generated Code Structure

**Drift generates:**
- `_$AppDatabase` base class with table accessors
- Data classes for each table (e.g., `Rechnung`, `Mitglied`)
- Companion classes for inserts/updates (e.g., `RechnungenCompanion`)
- Query builder methods

**Riverpod generates:**
- Provider instances from `@riverpod` annotations
- Provider families for parameterized providers
- Auto-dispose logic

**JSON Serializable generates:**
- `_$ClassNameFromJson()` functions
- `_$ClassNameToJson()` functions

## Success Criteria

The fix is successful when:
1. ✅ All `.g.dart` files are generated
2. ✅ `flutter analyze` reports no errors
3. ✅ Application builds successfully
4. ✅ Application runs without runtime errors
5. ✅ Database operations work correctly
6. ✅ All features are accessible

## Estimated Resolution Time

- **Code generation:** 1-2 minutes
- **Build verification:** 2-5 minutes
- **Testing:** 5-10 minutes
- **Total:** 10-15 minutes

## Prevention

To prevent this issue in the future:

1. **Documentation:** Add code generation instructions to README
2. **CI/CD:** Ensure build pipeline runs code generation
3. **Git Strategy:** 
   - Option A: Commit `.g.dart` files (easier for new developers)
   - Option B: Add to `.gitignore` and document generation requirement
4. **Pre-commit Hook:** Verify generated code is up-to-date
5. **Developer Onboarding:** Include code generation in setup instructions

## Related Files

### Configuration:
- [`pubspec.yaml`](pubspec.yaml:1) - Dependencies and dev dependencies
- [`analysis_options.yaml`](analysis_options.yaml:1) - Linter configuration

### Core Database:
- [`lib/core/database/database.dart`](lib/core/database/database.dart:1) - Main database definition
- [`lib/core/database/schema_versions.dart`](lib/core/database/schema_versions.dart:1) - Schema version history
- [`lib/core/database/tables/`](lib/core/database/tables/) - Table definitions

### Providers:
- [`lib/core/providers/database_provider.dart`](lib/core/providers/database_provider.dart:1) - Database singleton
- [`lib/core/providers/active_data_grid_provider.dart`](lib/core/providers/active_data_grid_provider.dart:1) - Active grid controller

## Conclusion

This is a **straightforward fix** requiring only code generation. The codebase structure is correct; it simply needs the build_runner to generate the missing `.g.dart` files. Once generated, all compilation errors should resolve automatically.

**Next Step:** Run the code generation commands and verify the build succeeds.
