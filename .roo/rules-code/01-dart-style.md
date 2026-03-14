# Dart Code-Mode Regeln

## Geltungsbereich

Diese Regeln gelten für den **Code-Mode** bei der Implementierung von Dart/Flutter Code.

## Code-Stil

### 1. Formatierung

- **Zeilenlänge**: 100 Zeichen (konfiguriert in analysis_options.yaml)
- **Einrückung**: 2 Leerzeichen
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

### 2. Imports

```dart
// ✅ RICHTIG: Geordnete Imports
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../models/member_row_data.dart';

// ❌ FALSCH: Ungeordnet, relative Pfade inkonsistent
import 'package:flutter/material.dart';
import '../../../core/database/database.dart';
import 'dart:async';
import '../models/member_row_data.dart';
```

### 3. Naming Conventions

| Element | Konvention | Beispiel |
|---------|------------|----------|
| Klassen | PascalCase | `MemberRepository` |
| Methoden/Funktionen | camelCase | `getMembers()` |
| Variablen | camelCase | `memberList` |
| Konstanten | lowerCamelCase | `defaultPageSize` |
| Enum-Werte | lowerCamelCase | `paymentStatusOpen` |
| Dateien | snake_case | `member_repository.dart` |
| Private Members | _prefix | `_internalCache` |

### 4. Typisierung

```dart
// ✅ RICHTIG: Explizite Typen
Future<List<Member>> getMembers() async { ... }

final List<Member> members = await repository.getMembers();

// ❌ FALSCH: var überall verwenden
var members = await repository.getMembers(); // Typ ist nicht klar
```

## Riverpod Best Practices

### 1. Provider-Definition

```dart
// ✅ RICHTIG: Code-generierte Provider mit @riverpod
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'members_repository.g.dart';

@riverpod
MembersRepository membersRepository(MembersRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return MembersRepository(db);
}

@riverpod
Stream<List<Member>> memberList(MemberListRef ref) {
  final repository = ref.watch(membersRepositoryProvider);
  return repository.watchAll();
}

// ❌ FALSCH: StateProvider für komplexe States
final membersProvider = StateProvider<List<Member>>((ref) => []);
```

### 2. AsyncValue Pattern

```dart
// ✅ RICHTIG: AsyncValue für asynchrone Daten
class MemberListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(memberListProvider);
    
    return membersAsync.when(
      data: (members) => _buildList(members),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler: $err')),
    );
  }
}
```

### 3. Ref.invalidate vs Ref.refresh

```dart
// ✅ RICHTIG: invalidate für Neuladen bei nächster Verwendung
ref.invalidate(memberListProvider);

// ✅ RICHTIG: refresh für sofortiges Neuladen
await ref.refresh(memberListProvider.future);
```

## Drift Database Patterns

### 1. Table Definition

```dart
// ✅ RICHTIG: Typisierte Tabellen mit Constraints
class MitgliedTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get vorname => text().withLength(min: 1, max: 100)();
  IntColumn get leistungId => integer().references(LeistungTable, #id).nullable()();
  DateTimeColumn get erstelltAm => dateTime().withDefault(currentDateAndTime)();
  
  @override
  List<String> get customConstraints => [
    'UNIQUE (name, vorname)',
  ];
}
```

### 2. Repository Pattern

```dart
// ✅ RICHTIG: Repository kapselt Datenbank-Logik
class MembersRepository {
  final AppDatabase _db;
  
  MembersRepository(this._db);
  
  Stream<List<Mitglied>> watchAll() {
    return _db.select(_db.mitgliedTable).watch();
  }
  
  Future<Mitglied?> getById(int id) {
    return (_db.select(_db.mitgliedTable)..where((m) => m.id.equals(id))).getSingleOrNull();
  }
  
  Future<int> insert(Companion<MitgliedTable> companion) {
    return _db.into(_db.mitgliedTable).insert(companion);
  }
  
  Future<bool> update(int id, Companion<MitgliedTable> companion) {
    return _db.update(_db.mitgliedTable).replace(companion);
  }
  
  Future<int> delete(int id) {
    return (_db.delete(_db.mitgliedTable)..where((m) => m.id.equals(id))).go();
  }
}
```

### 3. Transactions

```dart
// ✅ RICHTIG: Mehrere Operationen in Transaktion
Future<void> createBeitragWithHistory(BeitragData data) async {
  await _db.transaction(() async {
    final beitragId = await _db.into(_db.beitragTable).insert(data.beitrag);
    
    await _db.into(_db.beitragStatusVerlaufTable).insert(
      BeitragStatusVerlaufCompanion(
        beitragId: Value(beitragId),
        status: const Value(BeitragStatus.kontiert),
        bemerkung: const Value('Beitrag angelegt'),
        geaendertAm: Value(DateTime.now()),
      ),
    );
  });
}
```

## Widget Patterns

### 1. ConsumerWidget vs HookConsumerWidget

```dart
// ✅ RICHTIG: ConsumerWidget für einfache Fälle
class MemberListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) { ... }
}

// ✅ RICHTIG: HookConsumerWidget für Animationen/Controller
class MemberEditDialog extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextController();
    final scrollController = useScrollController();
    ...
  }
}
```

### 2. StatefulWidget (vermeiden wenn möglich)

```dart
// ✅ BESSER: Hooks statt StatefulWidget
class AnimatedMemberCard extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(duration: const Duration(milliseconds: 300));
    // ...
  }
}
```

### 3. Separation of Concerns

```dart
// ✅ RICHTIG: UI-Logik von Business-Logik trennen
// In Repository
class MembersRepository {
  Future<List<Member>> searchMembers(String query) async { ... }
}

// In Widget
class MemberSearchField extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Autocomplete<Member>(
      optionsBuilder: (text) => ref.read(membersRepositoryProvider).searchMembers(text),
      ...
    );
  }
}
```

## Fehlerbehandlung

### 1. Result Pattern für Operationen

```dart
// ✅ RICHTIG: Result-Typ für Operationen mit Fehlerfällen
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final String message;
  const Failure(this.message);
}

// Verwendung
Future<Result<void>> saveMember(Member member) async {
  try {
    await repository.update(member);
    return const Success(null);
  } on DriftWrappedException catch (e) {
    return Failure('Datenbankfehler: ${e.message}');
  }
}
```

### 2. User-Feedback

```dart
// ✅ RICHTIG: ScaffoldMessenger für SnackBars
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Mitglied erfolgreich gespeichert')),
);

// ✅ RICHTIG: Dialog für Bestätigungen
await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Löschen bestätigen'),
    content: const Text('Möchten Sie dieses Mitglied wirklich löschen?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Löschen'),
      ),
    ],
  ),
);
```

## Testing-Vorbereitung

```dart
// ✅ RICHTIG: Code testbar strukturieren
// Abhängigkeiten über Konstruktor injizieren
class MemberValidator {
  const MemberValidator();
  
  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name ist erforderlich';
    }
    if (value.length > 100) {
      return 'Name darf maximal 100 Zeichen haben';
    }
    return null;
  }
}
```

## Code-Generierung

- `build_runner` Befehle nur auf explizite Anfrage ausführen
- Generierte Dateien (*.g.dart, *.freezed.dart) nicht manuell bearbeiten
- Nach Änderungen an annotierten Klassen: `dart run build_runner build --delete-conflicting-outputs`
