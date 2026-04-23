# Projektspezifische Regeln – ClupData

## Projektspezifische Abhängigkeiten

### Runtime Dependencies
| Package | Version | Zweck |
|---------|---------|-------|
| `hooks_riverpod` | ^3.3.1 | State Management mit Code-Generation |
| `flutter_hooks` | ^0.21.3+1 | Hooks statt StatefulWidget |
| `drift` | ^2.31.0 | SQLite ORM (typsichere Queries) |
| `sqlite3_flutter_libs` | ^0.6.0+eol | SQLite Native Libraries |
| `go_router` | ^17.1.0 | Deklaratives Routing |
| `pluto_grid` | ^8.0.0 | Data Grid Komponente |
| `riverpod_annotation` | ^4.0.2 | Riverpod Code-Generation Annotations |
| `freezed_annotation` | ^3.1.0 | Immutable Data Classes Annotations |
| `json_annotation` | ^4.11.0 | JSON Serialization Annotations |
| `pdf` | ^3.10.0 | PDF-Generierung |
| `printing` | ^5.11.0 | Druck-Funktionalität |
| `csv` | ^8.0.0 | CSV Import/Export |
| `intl` | ^0.20.2 | Lokalisierung und Formatierung |
| `gap` | ^3.0.1 | Layout-Abstände (statt SizedBox) |
| `window_manager` | ^0.5.1 | Desktop Window Management |
| `mdi` | ^5.0.0-nullsafety.0 | Material Design Icons |
| `path_provider` | ^2.1.5 | Dateisystem-Pfade |
| `file_picker` | ^10.3.3 | Datei-Auswahl-Dialog |
| `pdf_merger` | ^0.0.6 | PDF-Zusammenführung |

### Dev Dependencies
| Package | Version | Zweck |
|---------|---------|-------|
| `build_runner` | ^2.12.2 | Code-Generation Runner |
| `drift_dev` | ^2.31.0 | Drift Code-Generation |
| `riverpod_generator` | ^4.0.2 | Riverpod Provider Code-Generation |
| `freezed` | ^3.2.5 | Immutable Data Classes Code-Generation |
| `json_serializable` | ^6.13.0 | JSON Serialization Code-Generation |
| `flutter_lints` | ^6.0.0 | Linting-Regeln |

## Erkannte Projektkonventionen

### Architektur
- **Feature-First-Struktur** unter `lib/features/<feature>/`
- **Layer-Architektur**: Data → Domain → Presentation
- **Single Source of Truth**: `lib/assets/data/structur.md` für DB-Schema und UI-Konfiguration
- **Repository Pattern**: Jedes Feature hat ein Repository in `data/`
- **Export-Architektur Split**: Feature-spezifisch in `lib/features/export/`, generisch in `lib/widgets/data_grid_v2/export/`

### State Management
- **AUSSCHLIESSLICH** `hooks_riverpod` mit Code-Generation (`@riverpod`)
- **NIEMALS** `StatefulWidget` – immer `flutter_hooks` verwenden
- **NIEMALS** `StateProvider` für komplexe States – `@riverpod` verwenden
- `ref.watch()` für reaktive Bindings, `ref.read()` für einmalige Aktionen
- `ref.invalidate()` für Neuladen bei nächster Verwendung
- `await ref.refresh()` für sofortiges Neuladen

### Datenbank (Drift)
- **AUSSCHLIESSLICH** `drift` für SQLite – niemals Raw SQL
- Tabellen als Dart-Klassen (`class Members extends Table`)
- Foreign Keys aktiviert (`PRAGMA foreign_keys = ON`)
- Migrations sind inkrementell – niemals Tabellen löschen ohne Datenmigration
- Bemerkung-Operationen zentralisiert in `lib/core/data/bemerkung_repository.dart`
- Status-Historie: Jeder Status-Wechsel MUSS protokolliert werden

### UI-Konventionen
- **Desktop-optimiert** (Maus & Tastatur) – keine Mobile-Paradigmen
- **Pluto Grid** exklusiv für tabellarische Daten – niemals DataTable/Table
- **Material 3** (`useMaterial3: true`) mit Desktop-Anpassungen
- **Tastaturbedienung**: Komplett über Tastatur bedienbar, Tab-Navigation
- **gap** Package statt `SizedBox(height: ...)` für Abstände
- **AppEditDialogScaffold** für alle Edit-Dialoge
- **AppDialogDeleteAction** für Löschen-Buttons mit Bestätigung
- Status-Farben aus zentraler Quelle – **NIEMALS** Hex-Werte hardcoden

### DataGrid-Regeln
- Generic Base Class `VpitDataGrid<T>` mit PlutoGrid
- Controller Pattern (`DataGridController<T>`) für State-Management
- Persistence Delegation über Callbacks (`onItemCreated`, `onItemUpdated`, `onItemDeleted`)
- Row-Mappings **NIEMALS** direkt im `build()` – `useMemoized` oder Provider verwenden
- Berechnete Felder im Provider, nicht im DataGrid/Dialog

### Export-Regeln
- Single Source of Truth: Export-Daten aus `DataGridController<T>`
- Generic Abstraction: Export-Funktionen dürfen nicht von Domain-Modellen abhängen
- `ExportDataTable` als generisches DTO für alle Output-Generatoren
- CSV: UTF-8 mit BOM für Excel-Kompatibilität
- PDF: Template-System mit `PdfTemplate`-Interface

### Performance-Regeln
- `ref.watch(provider.select((v) => v.field))` für selektives Rebuilding
- Streams statt Polling: Drift's `.watch()` für Listenansichten
- Kein Mapping im `build()` – `useMemoized` verwenden
- Berechnete Felder im Provider, nicht im Widget

### Sicherheit
- **NIEMALS** String-Interpolation in SQL-Queries
- Personenbezogene Daten sensibel behandeln
- Keine Daten in Logs ausgeben (außer IDs)
- Keine destruktiven Befehle (`rm -rf`, `DROP TABLE`)

## Eigene Entwicklungsmaßgaben
- Clean-Code und OOP Richtlinien beachten
- Maximale Wiederverwendbarkeit, keine Wiederholungen
- kein Over-Engineering. Simple is better than complicated
- Zum Implementieren wechsele in den Mode "Flutter Developer"