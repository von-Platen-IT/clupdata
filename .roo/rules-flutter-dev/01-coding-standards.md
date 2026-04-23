# Coding-Standards – Flutter Developer Mode

## Dart-Konventionen

### Formatierung (Projekt-spezifisch!)
- **Einrückung**: 2 Leerzeichen (nicht 4!)
- **Zeilenlänge**: 100 Zeichen
- **Trailing Commas**: Immer bei mehrzeiligen Strukturen

```dart
// ✅ RICHTIG
final result = await repository.getMembers(
  filter: filter,
  limit: 50,
  offset: 0,
);

// ❌ FALSCH
final result = await repository.getMembers(filter: filter, limit: 50, offset: 0);
```

### Import-Reihenfolge (STRIKT)
```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../models/member_row_data.dart';
```

### Naming Conventions
| Element | Konvention | Beispiel |
|---------|------------|----------|
| Klassen | PascalCase | `MemberRepository` |
| Methoden/Funktionen | camelCase | `getMembers()` |
| Variablen | camelCase | `memberList` |
| Konstanten | lowerCamelCase | `defaultPageSize` |
| Enum-Werte | lowerCamelCase | `paymentStatusOpen` |
| Dateien | snake_case | `member_repository.dart` |
| Private Members | _prefix | `_internalCache` |

### Typisierung
```dart
// ✅ RICHTIG: Explizite Typen
Future<List<Member>> getMembers() async { ... }
final List<Member> members = await repository.getMembers();

// ❌ FALSCH: var überall verwenden
var members = await repository.getMembers();
```

## Widget-Regeln
- **ConsumerWidget** für einfache Fälle
- **HookConsumerWidget** für Controller/Animationen (`useTextController()`, `useScrollController()`)
- **StatefulWidget VERMEIDEN** – immer `flutter_hooks` verwenden
- Dialoge: [`AppEditDialogScaffold`](lib/common_widgets/app_edit_dialog_scaffold.dart) aus `common_widgets/` verwenden
- Löschen: [`AppDialogDeleteAction`](lib/common_widgets/app_dialog_delete_action.dart) mit built-in confirmation
- Extrahiere Widgets in eigene Klassen ab ~50 Zeilen
- Nutze `const` überall wo möglich für Performance
- Kein Business-Logik in Widgets – nur UI-Logik

## State-Management (Riverpod mit Code-Generation)

### Provider-Definition
```dart
// ✅ RICHTIG: Code-generierte Provider mit @riverpod
@riverpod
MembersRepository membersRepository(MembersRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return MembersRepository(db);
}

// ❌ FALSCH: StateProvider für komplexe States
final membersProvider = StateProvider<List<Member>>((ref) => []);
```

### AsyncValue Pattern
```dart
final membersAsync = ref.watch(memberListProvider);

return membersAsync.when(
  data: (members) => _buildList(members),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, stack) => Center(child: Text('Fehler: $err')),
);
```

### Ref.invalidate vs Ref.refresh
- `ref.invalidate(provider)` – Neuladen bei nächster Verwendung
- `await ref.refresh(provider.future)` – sofortiges Neuladen
- `@Riverpod(keepAlive: true)` für globale Daten (z.B. `appDatabaseProvider`)

## Drift Database Patterns

### Repository Pattern
- Repositories in `features/<name>/data/<name>_repository.dart`
- Repository enthält NUR Klasse + `@riverpod` Provider
- Domain-Modelle in `features/<name>/domain/models/`
- UI-Provider in `features/<name>/presentation/providers/`

### Transactions
- Mehrere Operationen immer in Transaktion
- Bemerkung-Operationen zentralisiert in [`lib/core/data/bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart)

### Status-Historie Pattern
- Jeder Status-Wechsel bei `beitrag` MUSS in `beitrag_status_verlauf` protokolliert werden
- Bemerkung ist **Pflichtfeld** (NOT NULL)
- [`BeitraegeRepository.updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart) erkennt Status-Änderung automatisch

### Rechnungsnummer-Generierung
- Format: `RE-YYYY-XXXXX` (Jahr + 5-stellige Nummer)
- [`BeitraegeRepository.generateRechnungsnummer()`](lib/features/beitraege/data/beitraege_repository.dart) prüft auf Eindeutigkeit

## Status-Farben (VERBINDLICH – NIEMALS Hardcode Hex)
| Status | Farbe | Hex |
|--------|-------|-----|
| `kontiert` | Hellgelb | `#FFF9C4` |
| `offen` | Hellorange | `#FFE0B2` |
| `bezahlt` | Hellgrün | `#C8E6C9` |
| `angemahnt` | Hellrot | `#FFCDD2` |
| `storniert` | Hellgrau | `#EEEEEE` |
| `inkasso` | Pink | `#F8BBD0` |

Quelle: [`lib/features/beitraege/utils/beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart)

## Fehlerbehandlung
- Result-Pattern für Operationen mit Fehlerfällen (sealed class `Result<T>`)
- Keine unbehandelten Exceptions in der UI-Schicht
- ScaffoldMessenger für SnackBars, Dialog für Bestätigungen
- Kein `print()` in Production – dedizierten Logger verwenden

## Kommentare
- Öffentliche APIs: Dart-Doc (/// ...) ist Pflicht
- Komplexe Logik: Erkläre das "Warum", nicht das "Was"
- TODO-Kommentare: `// TODO(name): Beschreibung` – immer mit Autor

## Code-Generierung
- `flutter pub run build_runner build -d` nach Änderungen an `@riverpod`, `@DriftDatabase`, `@freezed`
- Generierte Dateien (*.g.dart, *.freezed.dart) **nie** manuell bearbeiten
- **Hot Reload funktioniert NICHT für generierten Code** – App neu starten!

## UI-Lokalisierung (Deutsch)
- Datumsformat: `dd.MM.yyyy`
- Zahlenformat: Deutsche Konvention (1.234,56)
- Währung: `123,45 €` (Symbol nach Betrag)
- Alle UI-Texte auf Deutsch
