# CLupData - Agent Documentation

> **WICHTIG**: Diese Datei ist die zentrale Dokumentation für KI-Coding-Agenten. Sie beschreibt die Architektur, Konventionen und Workflows des Projekts.

---

## 1. Project Overview

**CLupData** ist eine Desktop-Verwaltungssoftware für einen Boxclub. Die Anwendung ermöglicht die Verwaltung von Mitgliedern, Verträgen, Beiträgen, Warenwirtschaft und Rechnungsstellung.

### Hauptfeatures

| Feature | Beschreibung |
|---------|--------------|
| **Mitgliederverwaltung** | Stammdaten, Kontaktdaten, Vertragslaufzeiten, Leistungszuordnung |
| **Leistungskatalog** | Vertragsarten mit Preisen und Laufzeiten (einmalig/monatlich/quartalsweise/jährlich) |
| **Beitragsverwaltung** | Status-Tracking (kontiert → offen → bezahlt/angemahnt/storniert/inkasso) mit Historie |
| **Warenwirtschaft** | Artikelstamm, Bestand, Preise, Lieferanten |
| **Rechnungsstellung** | Kassenverkauf mit Rechnungserstellung |
| **Stammdaten** | Konfigurationsspeicher für MwSt, Firmendaten, Pfade |

---

## 2. Technology Stack

### Kern-Technologien

| Komponente | Technologie | Version | Zweck |
|------------|-------------|---------|-------|
| **Framework** | Flutter | 3.x | Cross-Platform UI (Desktop: Windows/Linux/macOS) |
| **State Management** | hooks_riverpod | ^3.3.1 | Reaktiver State mit Hooks |
| **Database** | Drift (SQLite) | ^2.31.0 | Lokale Datenpersistenz |
| **Routing** | go_router | ^17.1.0 | Deklarative Navigation |
| **Data Grids** | pluto_grid | ^8.0.0 | Tabellarische Datenansichten |
| **Window Management** | window_manager | ^0.5.1 | Desktop-Fenster-Verwaltung |
| **PDF/Printing** | pdf + printing | ^3.10.0 / ^5.11.0 | PDF-Generierung und Druck |
| **Icons** | mdi | ^5.0.0 | Material Design Icons |

### Code-Generierung

| Package | Zweck |
|---------|-------|
| `riverpod_generator` | Provider-Code-Generierung |
| `freezed` + `freezed_annotation` | Immutable Data Classes |
| `json_serializable` + `json_annotation` | JSON-Serialisierung |
| `drift_dev` | Datenbank-Code-Generierung |
| `build_runner` | Build-System für Code-Generierung |

### Dart/Flutter Version

```yaml
sdk: ^3.11.0
```

---

## 3. Project Structure

```
lib/
├── main.dart                           # Einstiegspunkt, Window-Setup
├── core/                               # Shared Kernel
│   ├── database/
│   │   ├── database.dart               # Drift Database Setup + Migrationen
│   │   ├── database.g.dart             # Generierter Code
│   │   └── tables/                     # Tabellen-Definitionen
│   │       ├── beitraege_table.dart
│   │       ├── beitrag_status_verlauf_table.dart
│   │       ├── bemerkung_table.dart
│   │       ├── leistung_table.dart
│   │       ├── mitglied_table.dart
│   │       ├── preis_table.dart
│   │       ├── rechnung_table.dart
│   │       ├── rechnung_position_table.dart
│   │       ├── stammdaten_table.dart
│   │       └── waren_table.dart
│   ├── providers/
│   │   ├── database_provider.dart      # AppDatabase Provider
│   │   ├── active_data_grid_provider.dart
│   │   └── export_context_provider.dart
│   ├── router/
│   │   └── app_router.dart             # go_router Konfiguration
│   ├── theme/
│   │   └── app_theme.dart              # Material 3 Theme (Light/Dark)
│   └── utils/
│       └── app_version.dart
├── common_widgets/                     # Wiederverwendbare UI-Komponenten
│   ├── app_dialog_delete_action.dart
│   ├── app_edit_dialog_scaffold.dart
│   ├── app_section_header.dart
│   ├── app_shell.dart                  # Haupt-Layout mit NavigationRail
│   ├── bemerkung_detail_view.dart
│   ├── feature_screen_scaffold.dart
│   ├── main_menu_bar.dart              # Global MenuBar (Export, etc.)
│   └── forms/                          # Formular-Felder
│       ├── app_date_picker_field.dart
│       ├── app_dropdown_field.dart
│       ├── app_entity_autocomplete.dart
│       ├── app_select_field.dart
│       └── app_text_field.dart
├── features/                           # Feature-Module (Feature-First Architektur)
│   ├── beitraege/                      # Beitragsverwaltung
│   ├── calendar/                       # Kalender-Modul
│   ├── dashboard/                      # Dashboard-Übersicht
│   ├── export/                         # Export-Feature (UI + Konfiguration, siehe §3.1)
│   ├── leistungen/                     # Leistungskatalog
│   ├── master_data/                    # Stammdaten-Dialoge
│   ├── members/                        # Mitgliederverwaltung
│   ├── pos/                            # Point of Sale (Kasse)
│   ├── rechnungen/                     # Rechnungsverwaltung
│   ├── stammdaten/                     # Einstellungen/Screen
│   └── waren/                          # Warenwirtschaft
├── widgets/                            # Shared Widgets (DataGrid)
│   └── data_grid_v2/                   # Generische DataGrid-Komponente
│       ├── vpit_data_grid.dart
│       ├── data_grid_controller.dart
│       ├── data_grid_column_config.dart
│       ├── sort_settings_dialog.dart
│       ├── filter_settings_dialog.dart
│       └── export/                     # PDF/CSV Export
│           ├── csv_exporter.dart
│           └── pdf/
│               ├── pdf_exporter.dart
│               ├── pdf_template.dart
│               ├── pdf_template_registry.dart
│               └── templates/
└── utils/
    └── app_debouncer.dart
```

### Feature-Modul-Struktur

Jedes Feature folgt diesem Muster:

```
features/<feature_name>/
├── <feature_name>_screen.dart          # Haupt-Screen
├── domain/
│   └── models/                         # Domain-Models (RowData, Detail-Wrapper)
├── data/
│   └── <feature>_repository.dart       # Repository-Klasse + Repository-Provider
├── presentation/
│   ├── dialogs/                        # Edit/Create Dialoge
│   ├── providers/                      # UI-State Provider (List-Streams, Detail-Provider)
│   └── widgets/                        # Feature-spezifische Widgets
└── utils/                              # Hilfsfunktionen
```

**Wichtige Konventionen:**

- **`data/<feature>_repository.dart`**: Enthält NUR die Repository-Klasse und den zugehörigen `@riverpod` Repository-Provider. Keine Domain-Modelle, keine UI-Provider.
- **`domain/models/`**: Alle Domain-Modelle (RowData für DataGrid-Anzeige, Detail-Wrapper für zusammengesetzte Daten). Modelle werden NICHT inline im Repository definiert.
- **`presentation/providers/`**: UI-Level Provider (z.B. List-Stream-Provider, Detail-Provider), die das Repository konsumieren. Getrennt vom Repository für klare Zuständigkeiten.

### §3.1 Export-Feature: Architektur-Aufteilung

Das Export-Feature ist bewusst auf zwei Verzeichnisse aufgeteilt:

| Verzeichnis | Verantwortlichkeit | Inhalt |
|-------------|-------------------|--------|
| `lib/features/export/` | **Feature-spezifisch** (UI + Konfiguration) | `domain/export_config.dart`, `presentation/dialog_export_button.dart`, `presentation/export_options_dialog.dart`, `presentation/list_export_menu_button.dart` |
| `lib/widgets/data_grid_v2/export/` | **Generische Export-Infrastruktur** (wiederverwendbar) | `csv_exporter.dart`, `export_data_table.dart`, `pdf/` (PDF-Exporter, Templates, Preview) |

**Begründung**: Die generische Export-Infrastruktur in `widgets/data_grid_v2/export/` ist unabhängig von jedem Feature und kann von jedem DataGrid genutzt werden. Das `features/export/`-Modul enthält hingegen die Feature-spezifische UI (Dialoge, Buttons) und die Export-Konfiguration (`ExportConfig`), die pro DataGrid individuell ist.

---

## 4. Database Architecture

### Tabellen-Übersicht

| Tabelle | Beschreibung | Relationen |
|---------|--------------|------------|
| `mitglied` | Mitgliederstammdaten | → leistung (n:1), → bemerkung (n:1) |
| `leistung` | Vertragsarten/Leistungen | → preis (n:1), → bemerkung (n:1) |
| `preis` | Preisdefinitionen | → bemerkung (n:1) |
| `beitrag` | Mitgliedsbeiträge/Rechnungen | → mitglied (n:1), → leistung (n:1), → preis (n:1) |
| `beitrag_status_verlauf` | Status-Historie (immutable) | → beitrag (n:1, CASCADE) |
| `waren` | Artikelstamm | → bemerkung (n:1) |
| `rechnung` | POS-Rechnungen | → mitglied (n:1, SET NULL), → bemerkung (n:1) |
| `rechnung_position` | Rechnungspositionen | → rechnung (n:1, CASCADE), → waren (n:1) |
| `stammdaten` | Konfiguration (Key-Value) | - |
| `bemerkung` | Freitext-Notizen | Wiederverwendbar |

### Schema-Version

```dart
@override
int get schemaVersion => 15;
```

### Migrationen

Migrationen werden in `database.dart` definiert. Das Projekt verwendet inkrementelle Migrationen:

```dart
onUpgrade: (migrator, from, to) async {
  if (from == 14) {
    // v15: Neue Spalte abrechnungsZeitraum in beitraege
    await migrator.addColumn(beitraege, beitraege.abrechnungsZeitraum);
  }
  // ... weitere Migrationen
}
```

### Datenbank-Datei

- **Development**: `clup_data_dev.sqlite` (im Projekt-Root)
- **Production**: `clup_data.sqlite` (neben der Executable)

---

## 5. Build and Test Commands

### Code-Generierung (Build Runner)

Code-Generierung ist **erforderlich** nach Änderungen an:
- `@riverpod` Annotationen
- `@DriftDatabase` Tabellen
- `@freezed` Klassen
- `@JsonSerializable` Klassen

```bash
# Einmalige Generierung
flutter pub run build_runner build -d

# Oder: Kontinuierliches Watch für Entwicklung
flutter pub run build_runner watch -d
```

### App Starten

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

### Tests

```bash
# Alle Tests ausführen
flutter test

# Mit Coverage
flutter test --coverage
```

**Aktueller Test-Status**: Das Projekt hat minimale Testabdeckung (`test/widget_test.dart` ist ein Standard-Template-Test).

### Analyse

```bash
# Statische Analyse
flutter analyze

# Formatierung prüfen
dart format --output=none --set-exit-if-changed .
```

---

## 6. Code Style Guidelines

### Allgemeine Regeln

- **Sprache**: Code auf Englisch, UI-Texte auf Deutsch
- **Line Length**: 80 Zeichen (Standard Dart)
- **Imports**: Organisiert durch `organize_imports` (IDE-Einstellung)

### Naming Conventions

| Element | Konvention | Beispiel |
|---------|------------|----------|
| Klassen | PascalCase | `MembersRepository`, `MitgliedEditDialog` |
| Dateien | snake_case | `members_repository.dart` |
| Provider | camelCase + Provider | `membersRepositoryProvider` |
| Tabellen | Plural + s | `Mitglieds`, `Beitraege` |
| Data Classes | Singular | `Mitglied`, `Beitrag` |
| Private Member | Unterstrich-Präfix | `_db`, `_selectedMember` |

### State Management Pattern

```dart
// Repository als Riverpod Provider
@riverpod
MembersRepository membersRepository(Ref ref) {
  return MembersRepository(ref.watch(appDatabaseProvider));
}

// Verwendung im Widget
final repository = ref.watch(membersRepositoryProvider);
```

### Immutability (Freezed)

```dart
@freezed
class MemberRowData with _$MemberRowData {
  const factory MemberRowData({
    required int id,
    required String name,
    required String vorname,
    String? ort,
  }) = _MemberRowData;

  factory MemberRowData.fromJson(Map<String, Object?> json) =>
      _$MemberRowDataFromJson(json);
}
```

### Widget Patterns

```dart
// ✅ ConsumerWidget für einfachen Zugriff auf Riverpod
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersListProvider);
    // ...
  }
}

// ✅ StatefulHookConsumerWidget für lokale State + Hooks
class MemberEditDialog extends StatefulHookConsumerWidget {
  // ...
}

// ✅ const Konstruktoren wo möglich
const SizedBox(height: 16)
```

---

## 7. UI/UX Conventions

### Deutsche Lokalisierung

| Format | Beispiel |
|--------|----------|
| Datum | `dd.MM.yyyy` (z.B. 24.03.2026) |
| Zahlen | `1.234,56` (deutsches Format) |
| Währung | `123,45 €` (Symbol nach Betrag) |

### Status-Farben (VERBINDLICH)

| Status | Farbe | Hex | Verwendung |
|--------|-------|-----|------------|
| `kontiert` | Hellgelb | `#FFF9C4` | Neu angelegt |
| `offen` | Hellorange | `#FFE0B2` | Ausstehend |
| `bezahlt` | Hellgrün | `#C8E6C9` | Bezahlt |
| `angemahnt` | Hellrot | `#FFCDD2` | Zahlungserinnerung |
| `storniert` | Hellgrau | `#EEEEEE` | Storniert |
| `inkasso` | Pink | `#F8BBD0` | Inkasso |

**Zentrale Quelle**: `lib/features/beitraege/utils/beitrag_status_colors.dart`

### Formularfelder

Verwende die zentralen Formular-Widgets:

```dart
// Text-Eingabe
AppTextField(
  label: 'Name',
  controller: nameController,
  validator: (value) => value?.isEmpty ?? true ? 'Pflichtfeld' : null,
)

// Datumsauswahl
AppDatePickerField(
  label: 'Geburtsdatum',
  selectedDate: selectedDate,
  onDateSelected: (date) => setState(() => selectedDate = date),
)

// Dropdown
AppDropdownField<String>(
  label: 'Anrede',
  value: selectedAnrede,
  items: ['Herr', 'Frau', 'Divers', 'Keine'],
  onChanged: (value) => setState(() => selectedAnrede = value),
)
```

### DataGrid Konfiguration

```dart
AppDataGridV2<MemberRowData>(
  columnConfigs: [
    DataGridColumnConfig(
      field: 'name',
      header: 'Name',
      width: 150,
      sortable: true,
      filterable: true,
    ),
    // ...
  ],
  rowData: members,
  onRowDoubleTap: (row) => openEditDialog(row),
)
```

---

## 8. Testing Instructions

### Aktueller Status

- Minimale Testabdeckung
- Ein Standard Flutter Widget-Test existiert
- Feature-Tests sollten hinzugefügt werden

### Testing Best Practices

```dart
// Repository-Test
void main() {
  late AppDatabase database;
  late MembersRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = MembersRepository(database);
  });

  tearDown(() => database.close());

  test('adds and retrieves member', () async {
    final id = await repository.addMember(
      MitgliedsCompanion.insert(name: 'Mustermann', vorname: 'Max'),
    );
    final member = await repository.getMemberById(id);
    expect(member?.name, 'Mustermann');
  });
}
```

### Widget-Test

```dart
testWidgets('shows member list', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: MembersScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Mitglieder'), findsOneWidget);
});
```

---

## 9. Security Considerations

### SQL-Injection-Schutz

- **NIE** String-Interpolation in SQL-Queries verwenden
- Drift's Type-Safe API nutzen

```dart
// ✅ RICHTIG: Type-safe Drift API
final query = db.select(db.mitglieds)
  ..where((m) => m.name.equals(name));

// ❌ FALSCH: String-Interpolation
await db.customQuery("SELECT * FROM mitglied WHERE name = '$name'");
```

### Datenschutz

- Personenbezogene Daten sensibel behandeln
- Keine Mitgliedsdaten in Logs ausgeben (nur IDs)
- Backup-Verzeichnis (`pfad_backup` in Stammdaten) sicher konfigurieren

### Datenbank-Sicherheit

- Datenbank-Datei liegt lokal neben der Executable
- Keine Netzwerk-Kommunikation
- Keine Cloud-Integration

---

## 10. Development Workflow

### Single Source of Truth (SSOT)

**Die Datei `lib/assets/data/structur.md` ist die zentrale Spezifikation.**

Vor jeder Änderung an:
- Datenbanktabellen
- Relationen
- UI-Screens/Konfiguration

**MUSST** du:
1. structur.md lesen und aktualisieren
2. Änderungen implementieren
3. Dokumentation synchron halten

### Feature-Entwicklung Workflow

1. **Datenmodell**: structur.md aktualisieren
2. **Datenbank**: Tabelle/Spalte in `core/database/tables/` hinzufügen
3. **Migration**: Schema-Version erhöhen, Migration in `database.dart` definieren
4. **Repository**: Repository-Provider in `features/<name>/data/` erstellen
5. **UI**: Screen + Dialoge in `features/<name>/presentation/` erstellen
6. **Routing**: Route in `app_router.dart` registrieren
7. **Code-Generierung**: `flutter pub run build_runner build -d`

### Verzeichnis für externe Dokumentation

| Datei | Zweck |
|-------|-------|
| `lib/assets/data/structur.md` | Vollständiges Datenbank-Schema + UI-Konfiguration |
| `.roo/rules/01-flutter-general.md` | Allgemeine Flutter/Dart Regeln |
| `plans/` | Architektur-Pläne und Feature-Spezifikationen |
| `drift_schemas/` | Datenbank-Schema-Versionen (für Migrationen) |

---

## 11. Important Files Reference

| Datei | Zweck |
|-------|-------|
| `lib/main.dart` | App-Einstieg, Window-Setup, PDF-Template-Registrierung |
| `lib/core/database/database.dart` | Drift Setup, Tabellen, Migrationen (Schema v15) |
| `lib/core/router/app_router.dart` | go_router Konfiguration mit StatefulShellRoute |
| `lib/core/theme/app_theme.dart` | Material 3 Theme (DeepOrange Seed) |
| `lib/core/providers/database_provider.dart` | Globaler AppDatabase Provider |
| `lib/common_widgets/app_shell.dart` | Haupt-Layout mit NavigationRail |
| `lib/common_widgets/main_menu_bar.dart` | Global MenuBar (Export, Druck) |
| `pubspec.yaml` | Dependencies und Projekt-Metadaten |
| `analysis_options.yaml` | Dart Linter Konfiguration |

---

## 12. Common Pitfalls

### Code-Generierung vergessen

Nach Änderungen an `@riverpod`, `@DriftDatabase`, `@freezed` **MUSS** `build_runner` laufen:

```bash
flutter pub run build_runner build -d
```

### Hot Reload bei generiertem Code

Hot Reload funktioniert **NICHT** bei Änderungen an generiertem Code. App neu starten.

### Datenbank-Migrationen

- Schema-Version in `database.dart` erhöhen
- Migration definieren (keine destruktiven Operationen ohne Backup)
- `schemaVersion` = aktuelle Version

### Desktop-Constraints

- UI ist für Desktop optimiert (Maus + Tastatur)
- Keine Mobile-Patterns (Swipe, etc.)
- `VisualDensity.compact` wird verwendet

---

## 13. Dependencies (pubspec.yaml)

### Production Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  hooks_riverpod: ^3.3.1
  flutter_hooks: ^0.21.3+1
  drift: ^2.31.0
  sqlite3_flutter_libs: ^0.6.0+eol
  path_provider: ^2.1.5
  path: ^1.9.1
  go_router: ^17.1.0
  gap: ^3.0.1
  window_manager: ^0.5.1
  mdi: ^5.0.0-nullsafety.0
  riverpod_annotation: ^4.0.2
  freezed_annotation: ^3.1.0
  json_annotation: ^4.11.0
  pluto_grid: ^8.0.0
  intl: ^0.20.2
  pdf: ^3.10.0
  printing: ^5.11.0
  flutter_localizations:
    sdk: flutter
  csv: ^8.0.0
```

### Dev Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.12.2
  drift_dev: ^2.31.0
  riverpod_generator: ^4.0.2
  build_verify: ^3.1.1
  freezed: ^3.2.5
  json_serializable: ^6.13.0
```

---

## 14. Agent Mode Guidelines

### Verfügbare Modi

| Modus | Zweck | Wann verwenden |
|-------|-------|----------------|
| **Architect** | Architektur-Planung, Datenbank-Design | Neue Features, Schema-Änderungen |
| **Code** | Implementierung, Bugfixes | Code schreiben, Tests erstellen |
| **Ask** | Erklärungen, Dokumentation | Code-Review, Konzepte klären |
| **Debug** | Fehlersuche, Diagnose | Exceptions, Performance-Probleme |

### Schnellwahl

| Situation | Modus |
|-----------|-------|
| "Wie soll ich X implementieren?" | architect |
| "Implementiere X" | code |
| "Erkläre mir X" | ask |
| "Warum funktioniert X nicht?" | debug |

---

*Dokumentation erstellt am 2026-03-30. Bei Unklarheiten: structur.md lesen, dann fragen.*
