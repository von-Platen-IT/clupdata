# Test-Standards – Flutter Tester Mode

## Pflichtregeln
- Jede neue Funktion in der Domain-Schicht braucht Unit-Tests
- Jedes neue Widget braucht Widget-Tests
- Testabdeckung-Ziel: > 80% für lib/
- Tests laufen mit: `flutter test --coverage`

## Teststruktur
```
test/
├── unit/          # Pure Dart Unit-Tests
│   ├── repositories/   # Repository-Tests
│   ├── services/       # Service-Tests
│   └── models/         # Model-Tests
├── widget/        # Flutter Widget-Tests
│   ├── dialogs/        # Dialog-Tests
│   ├── grids/          # DataGrid-Tests
│   └── forms/          # Form-Widget-Tests
└── integration/   # Integration-Tests
```

## Mock-Strategie
- Verwende **mocktail** (null-safety-freundlich, keine Code-Generation nötig)
- Erstelle Mocks im Ordner `test/mocks/`
- Bei Bedarf: `@GenerateMocks` mit mockito + build_runner (nur wenn mocktail nicht ausreicht)

### Drift-Tests
- Verwende **In-Memory-Datenbank** für Tests:
```dart
// ✅ RICHTIG: In-Memory DB für Tests
AppDatabase testDb = AppDatabase(NativeDatabase.memory());

// ❌ FALSCH: Echte Datenbank in Tests
AppDatabase testDb = AppDatabase(); // Greift auf echte DB zu!
```

### Riverpod-Tests
- Verwende `ProviderContainer` mit Overrides:
```dart
// ✅ RICHTIG: ProviderContainer mit Overrides
final container = ProviderContainer(
  overrides: [
    databaseProvider.overrideWithValue(testDb),
  ],
);
```

## Namenskonvention
- Testdateien: `<feature>_test.dart`
- Test-Beschreibungen: `should_<erwartetes_verhalten>_when_<zustand>`
- Gruppierung: `group('FeatureName', () { ... })`

## AAA-Pattern (Arrange, Act, Assert)
```dart
test('should_returnMembers_when_filterIsActive', () async {
  // Arrange
  final repository = MembersRepository(testDb);
  await repository.insert(testMember);

  // Act
  final result = await repository.getMembers(filter: activeFilter);

  // Assert
  expect(result, hasLength(1));
  expect(result.first.name, equals('Test'));
});
```

## Projekt-spezifische Test-Hinweise

### Repository-Tests
- Jedes Repository in `features/<name>/data/` braucht entsprechende Tests
- Teste CRUD-Operationen: Insert, Update, Delete, Watch
- Teste Edge-Cases: NULL-Werte, leere Listen, ungültige IDs

### Status-Historie Tests
- Status-Wechsel MUSS Eintrag in `beitrag_status_verlauf` erstellen
- Bemerkung ist Pflichtfeld – Teste dass NULL-Bemerkung fehlschlägt

### Export-Tests
- Teste `ExportDataTable`-Erstellung aus `DataGridController`
- Teste CSV-Export mit UTF-8 BOM
- Teste PDF-Template-Generierung

### Widget-Tests
- Verwende `ConsumerWidgetTester` für Riverpod-Widgets
- Teste Dialog-Interaktionen (Öffnen, Speichern, Abbrechen)
- Teste DataGrid-Darstellung und -Interaktion
