# AskKimi - Projektübersicht & Antwortvorbereitung

## Projektübersicht

**ClupData** ist eine Flutter Desktop-Anwendung für Vereinsverwaltung mit folgenden Kernmerkmalen:

- **Framework**: Flutter 3.x (Desktop: Windows/Linux/macOS)
- **Sprache**: Dart 3.11.0+
- **State Management**: Riverpod (hooks_riverpod) mit Code-Generation
- **Datenbank**: Drift (SQLite) für lokale Datenspeicherung
- **Routing**: go_router für deklaratives Routing
- **UI-Komponenten**: Pluto Grid für Data Grids, Material Design 3
- **Lokalisierung**: Deutsch (de_DE)

## Architektur-Übersicht

### Projektstruktur
```
lib/
├── core/                    # Shared Kernel
│   ├── database/           # Drift Database
│   ├── providers/         # Globale Riverpod Providers
│   ├── router/            # GoRouter Configuration
│   └── theme/             # AppTheme & Styling
├── common_widgets/        # Shared UI Components
│   └── forms/             # Form Field Widgets
└── features/              # Feature Modules
    ├── members/           # Mitgliederverwaltung
    ├── beitraege/         # Beitragsverwaltung
    ├── leistungen/        # Leistungskatalog
    ├── waren/             # Warenwirtschaft
    ├── rechnungen/        # Rechnungsstellung
    └── stammdaten/        # Einstellungen
```

### Layer-Architektur
1. **Data Layer**: Repositories kapseln Datenbankzugriff
2. **Domain Layer**: Models mit Business-Logik (keine Flutter-Dependencies)
3. **Presentation Layer**: Widgets und Riverpod Providers

## Technologie-Stack Details

### Flutter & Dart Versionen
- **Flutter SDK**: 3.x (aktuellste stabile Version)
- **Dart SDK**: ^3.11.0
- **Build**: Desktop-optimiert für Windows/Linux/macOS

### Wichtige Dependencies
- **hooks_riverpod**: ^3.3.1 (State Management)
- **drift**: ^2.31.0 (SQLite Database)
- **go_router**: ^17.1.0 (Navigation)
- **pluto_grid**: ^8.0.0 (Data Grid Komponenten)
- **freezed_annotation**: ^3.1.0 (Immutable Models)
- **window_manager**: ^0.5.1 (Desktop Window Management)

### Datenbank-Schema
- **Schema Version**: 15 (siehe `database.dart`)
- **Tabellen**: 10 Haupttabellen mit Relationen
- **Migration**: Drift MigrationStrategy implementiert

## Single Source of Truth

Die Datei [`lib/assets/data/structur.md`](lib/assets/data/structur.md) ist die zentrale Spezifikation für:
- Datenbank-Tabellenstruktur
- Felddefinitionen und Constraints
- UI-Konfiguration
- Geschäftslogik-Regeln

## Navigation & Routing

### Haupt-Routen
- `/` - Dashboard
- `/members` - Mitgliederverwaltung
- `/leistungen` - Leistungskatalog
- `/beitraege` - Beitragsverwaltung
- `/waren` - Warenwirtschaft
- `/rechnungen` - Rechnungsstellung
- `/stammdaten` - Einstellungen

### Navigation-Pattern
- **ShellRoute**: Persistente Navigation mit AppShell
- **Deep Linking**: Vollständige URL-basierte Navigation
- **Dialog Routes**: Für Edit-Dialoge

## UI/UX Standards

### Design System
- **Material Design 3**: Vollständige Material 3 Implementierung
- **Farbschema**: Blau-basiertes Theme mit dynamischen Farben
- **Typografie**: Deutsche Lokalisierung
- **Abstände**: Konsistente 8px Grid-Basis

### Status-Farben (Beiträge)
- `kontiert`: Hellgelb (#FFF9C4)
- `offen`: Hellorange (#FFE0B2)
- `bezahlt`: Hellgrün (#C8E6C9)
- `angemahnt`: Hellrot (#FFCDD2)
- `storniert`: Hellgrau (#EEEEEE)
- `inkasso`: Pink (#F8BBD0)

## Datenfluss & Listen-/Detail-Darstellung

### 1. Listen-/Detail-Darstellung: Wie funktioniert das Zusammenspiel?

#### **Warum diese Architektur?**
Die Trennung von Listen und Detailansichten folgt dem **CQRS-Prinzip** (Command Query Responsibility Segregation) - Lesen und Schreiben werden getrennt behandelt. Dies ermöglicht:
- **Performance**: Listen laden nur notwendige Daten
- **UX**: Details werden nur bei Bedarf geladen
- **Wartbarkeit**: Klare Trennung der Verantwortlichkeiten

#### **Wie funktioniert die Darstellung?**

**Phase 1: Listenansicht**
1. **Data Grid** (PlutoGrid) zeigt aggregierte Daten an
2. **Repository** liefert Stream-basierte Live-Updates
3. **RowData Models** kapseln die Darstellungslogik

**Phase 2: Detail-Dialog**
1. **Modaler Dialog** wird als Route geöffnet
2. **EditNotifier** lädt vollständige Entität
3. **Form-Widgets** binden sich an State

**Beispiel Members:**
```dart
// Listenansicht: MemberRowData (lightweight)
class MemberRowData {
  final int id;
  final String name;
  final String vorname;
  final String? leistungName; // Aggregiert aus Relation
}

// Detailansicht: Mitglied (vollständige Entität)
class Mitglied {
  final int id;
  final String name;
  final String vorname;
  final int? leistungId; // FK für Relation
  final String? plz;
  final String? ort;
  // ... weitere Felder
}
```

### 2. Datenherkunft & Speicherung: Der vollständige Datenfluss

#### **Warum SQLite + Drift?**
- **Offline-First**: Keine Internetverbindung erforderlich
- **ACID-Compliance**: Transaktionssicherheit für Finanzdaten
- **Type-Safety**: Drift generiert type-sichere Queries
- **Performance**: Lokale Datenbank für Desktop-Apps optimal

#### **Wie fließen die Daten?**

**Schicht 1: Datenbank (SQLite)**
```
SQLite File → Drift Database → Typed Tables
```

**Schicht 2: Repository Pattern**
```dart
// Repository kapselt DB-Zugriff
class MembersRepository {
  // Live-Updates für Listen
  Stream<List<MemberRowData>> watchAllMapped() {
    return (select(mitglieds)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .join([leftOuterJoin(leistung, leistung.id.equalsExp(mitglieds.leistungId))])
      .watch()
      .map((rows) => rows.map((row) => MemberRowData.fromMitglied(
        row.readTable(mitglieds),
        leistung: row.readTableOrNull(leistung),
      )).toList());
  }
  
  // Einzelne Entität für Details
  Future<Mitglied?> getById(int id) {
    return (select(mitglieds)..where((t) => t.id.equals(id))).getSingleOrNull();
  }
}
```

**Schicht 3: State Management (Riverpod)**
```dart
// Listen-Provider: Liefert aggregierte Daten
@riverpod
class MembersListNotifier extends _$MembersListNotifier {
  @override
  Future<List<MemberRowData>> build() async {
    final repository = ref.watch(membersRepositoryProvider);
    return repository.watchAllMapped().first; // Erste Ladung
  }
}

// Detail-Provider: Liefert vollständige Entität
@riverpod
class MemberEditNotifier extends _$MemberEditNotifier {
  @override
  Future<Mitglied> build(int memberId) async {
    final repository = ref.watch(membersRepositoryProvider);
    return repository.getById(memberId).then((value) => 
      value ?? throw Exception('Mitglied nicht gefunden'));
  }
}
```

### 3. Generischer Datenzugriff: API für zukünftige Klassen

#### **Warum generischer Zugriff?**
- **Erweiterbarkeit**: Neue Features ohne Boilerplate
- **Konsistenz**: Einheitliche Schnittstelle über alle Entitäten
- **Wiederverwendbarkeit**: Gemeinsame Logik in Basis-Klassen

#### **Wie funktioniert der generische Zugriff?**

**Basis-Interface für alle Entitäten:**
```dart
// Generisches Repository-Interface
abstract class CrudRepository<T, ID> {
  Stream<List<T>> watchAll();
  Future<T?> getById(ID id);
  Future<ID> insert(T entity);
  Future<bool> update(T entity);
  Future<int> delete(ID id);
}

// Generischer List-Provider
@riverpod
class GenericListNotifier<T, ID> extends _$GenericListNotifier<T, ID> {
  final CrudRepository<T, ID> Function(Ref) repositoryProvider;
  
  @override
  Future<List<T>> build() async {
    final repository = repositoryProvider(ref);
    return repository.watchAll().first;
  }
}
```

## Klassenübersicht: Aufgabenverteilung im Datenfluss

### **Datenbank-Schicht (SQLite + Drift)**

| Klasse | Aufgabe | Verantwortlichkeit |
|---|---|---|
| `AppDatabase` | Zentrale Datenbank-Koordination | Verwaltet alle Tabellen und Migrationen |
| `MitgliedTable` | Tabellendefinition | Struktur und Constraints für Mitglieder |
| `LeistungTable` | Tabellendefinition | Struktur und Constraints für Leistungen |
| `BeitragTable` | Tabellendefinition | Struktur und Constraints für Beiträge |
| `PreisTable` | Tabellendefinition | Preis- und Währungsverwaltung |

### **Repository-Schicht (Data Access)**

| Klasse | Aufgabe | Verantwortlichkeit |
|---|---|---|
| `MembersRepository` | Mitglied-Datenzugriff | CRUD-Operationen + Queries für Mitglieder |
| `LeistungenRepository` | Leistungs-Datenzugriff | CRUD-Operationen + Queries für Leistungen |
| `BeitraegeRepository` | Beitrags-Datenzugriff | CRUD-Operationen + Status-Verwaltung |
| `RechnungenRepository` | Rechnungs-Datenzugriff | Rechnungsstellung + Positionen |
| `WarenRepository` | Waren-Datenzugriff | Lagerbestand + Preisverwaltung |

### **State Management-Schicht (Riverpod)**

| Klasse | Aufgabe | Verantwortlichkeit |
|---|---|---|
| `MembersListNotifier` | Listen-State | Lädt und verwaltet Mitglieder-Listen |
| `MemberEditNotifier` | Detail-State | Lädt und verwaltet einzelne Mitglieder |
| `LeistungenListProvider` | Listen-State | Lädt und verwaltet Leistungs-Listen |
| `BeitragListNotifier` | Listen-State | Lädt und verwaltet Beitrags-Listen |
| `GenericListNotifier` | Generischer State | Wiederverwendbare Listen-Logik |

### **UI-Schicht (Presentation)**

| Klasse | Aufgabe | Verantwortlichkeit |
|---|---|---|
| `MemberDataGrid` | Listen-Darstellung | Zeigt Mitglieder in PlutoGrid an |
| `MemberEditDialog` | Detail-Dialog | Bearbeitungsformular für Mitglieder |
| `LeistungDataGrid` | Listen-Darstellung | Zeigt Leistungen in PlutoGrid an |
| `LeistungEditDialog` | Detail-Dialog | Bearbeitungsformular für Leistungen |
| `AppEditDialogScaffold` | Dialog-Template | Gemeinsame Dialog-Struktur |

### **Data Transfer Objects**

| Klasse | Aufgabe | Verantwortlichkeit |
|---|---|---|
| `MemberRowData` | Listen-Darstellung | Aggregierte Daten für Data Grid |
| `LeistungRowData` | Listen-Darstellung | Aggregierte Daten für Data Grid |
| `WarenRowData` | Listen-Darstellung | Aggregierte Daten für Data Grid |
| `Mitglied` | Vollständige Entität | Alle Felder für Detailansicht |
| `Leistung` | Vollständige Entität | Alle Felder für Detailansicht |

### **Generische Basis-Klassen**

| Klasse | Aufgabe | Verantwortlichkeit |
|---|---|---|
| `CrudRepository<T,ID>` | Generisches Interface | Einheitliche Repository-Schnittstelle |
| `RowData<T>` | Generisches Interface | Einheitliche Listen-Darstellung |
| `GenericEditDialog<T>` | Generischer Dialog | Wiederverwendbare Detail-Ansicht |
| `GenericDataGrid<T>` | Generisches Grid | Wiederverwendbare Listen-Ansicht |

### **Utility-Klassen**

| Klasse | Aufgabe | Verantwortlichkeit |
|---|---|---|
| `AppDatabase` | Datenbank-Setup | Verbindung und Migration |
| `DatabaseProvider` | Provider-Setup | Globale Datenbank-Instanz |
| `AppRouter` | Navigation | Route-Definition und Deep-Linking |
| `AppTheme` | Styling | Konsistentes Design-System |

### **Zusammenhang: Datenfluss durch die Schichten**

```
SQLite → Repository → Provider → Widget → User
   ↑         ↑         ↑        ↑        ↑
Migration  Queries   State   Rendering  Interaction
   ↓         ↓         ↓        ↓        ↓
Schema   Business   State   Rendering  Events
```

### **Beispiel-Datenfluss: Mitglied anzeigen & bearbeiten**

1. **User klickt auf Mitglieder-Screen**
   - `MembersListNotifier` → `MembersRepository` → `AppDatabase` → SQLite
   - Daten werden als `List<MemberRowData>` geliefert

2. **User klickt auf Mitglied bearbeiten**
   - `MemberEditDialog` → `MemberEditNotifier` → `MembersRepository` → SQLite
   - Vollständiges `Mitglied` Objekt wird geladen

3. **User speichert Änderungen**
   - `MemberEditDialog` → `MemberEditNotifier` → `MembersRepository` → SQLite
   - `MembersListNotifier` invalidiert automatisch → UI aktualisiert sich

### **Erweiterbarkeit für neue Klassen**

**Neue Entität hinzufügen:**
1. **Datenbank**: Neue Table-Klasse erstellen
2. **Repository**: Repository implementiert `CrudRepository`
3. **RowData**: RowData-Klasse für Listen-Darstellung
4. **Provider**: List- und Edit-Notifier registrieren
5. **UI**: Generische Komponenten (`GenericDataGrid`, `GenericEditDialog`) nutzen

**Vorteil**: Nur Schritt 1-3 sind entitäts-spezifisch, Schritt 4-5 nutzen generische Implementierungen.

## State Management Pattern

### Riverpod Provider Typen
1. **AsyncNotifier**: Für komplexe Async-States
2. **StreamProvider**: Für Live-Daten aus der DB
3. **StateNotifier**: Für UI-States
4. **FutureProvider**: Für einmalige Datenladung

### Repository Pattern
- **MembersRepository**: Mitgliederverwaltung
- **BeitraegeRepository**: Beitragsverwaltung
- **LeistungenRepository**: Leistungskatalog
- **RechnungenRepository**: Rechnungsstellung
- **WarenRepository**: Warenwirtschaft

## Entwicklungs-Workflow

### Code-Generierung
- **build_runner**: Für @riverpod, @freezed, @DriftDatabase
- **Generierte Dateien**: `*.g.dart`, `*.drift.dart`

### Testing
- **Unit Tests**: Repository-Tests mit In-Memory DB
- **Widget Tests**: Mit Provider Overrides
- **Integration Tests**: Desktop-spezifische Tests

### Performance-Optimierung
- **Lazy Loading**: In Data Grids implementiert
- **const Widgets**: Wo immer möglich
- **Selective Rebuilds**: Mit Riverpod select()

## Sicherheit & Datenschutz

### Datenbank-Sicherheit
- **SQL-Injection-Schutz**: Drift's Type-Safe API
- **Input-Validierung**: An allen Eingabepunkten
- **Backup-Strategie**: Konfigurierbar über Stammdaten

### Datenschutz
- **Lokale Speicherung**: Keine Cloud-Synchronisation
- **Personenbezogene Daten**: Sensibel behandelt
- **Logging**: Keine sensiblen Daten in Logs

## Deployment

### Desktop-Builds
- **Windows**: MSIX-Installer
- **Linux**: AppImage/Deb-Paket
- **macOS**: DMG-Installer

### Versionierung
- **Semantische Versionierung**: 1.0.0+1
- **Build-Nummer**: Automatisch inkrementiert
- **Release-Notes**: Automatisch generiert

## Frage-Kategorien

### 1. Architektur & Design
- Clean Architecture Prinzipien
- Repository Pattern Implementierung
- State Management Patterns
- Dependency Injection

### 2. Datenbank & Drift
- Tabellendesign und Relationen
- Migration-Strategien
- Performance-Optimierung
- Query-Optimierung

### 3. Flutter & Dart
- Widget Lifecycle
- Riverpod Best Practices
- Desktop-spezifische Implementierungen
- Performance-Tuning

### 4. UI/UX
- Material 3 Design System
- Responsive Design für Desktop
- Accessibility
- Deutsche Lokalisierung

### 5. Testing & Qualität
- Unit Testing Strategien
- Widget Testing Patterns
- Code-Generierung
- Linting & Formatierung

### 6. Deployment & DevOps
- Desktop Build-Prozesse
- CI/CD Pipelines
- Version Management
- Release-Strategien

## Dokumentations-Quellen

- **structur.md**: Zentrale Spezifikation
- **README.md**: Projekt-Setup und Installation
- **DatabaseMigration.md**: Migration-Details
- **AGENTS.md**: Agent-Konfiguration und Modi
- **Code-Kommentare**: Ausführliche Inline-Dokumentation