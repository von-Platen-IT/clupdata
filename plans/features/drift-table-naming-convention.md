# Plan: Drift Table-Naming-Konventionen durchsetzen

## Problem

Die SQLite-Tabellennamen in der Datenbank weichen von der kanonischen Spezifikation in [`structur.md`](lib/assets/data/structur.md) ab. Drift leitet den SQLite-Tabellennamen aus dem Dart-Klassennamen ab (PascalCase → snake_case), was zu falschen Pluralformen führt.

### Diskrepanz-Tabelle

| structur.md (Kanonisch) | Drift-Klasse | `@DataClassName` | Aktuelle SQLite-Tabelle | Soll SQLite-Tabelle | Status |
|--------------------------|-------------|-------------------|-------------------------|--------------------|--------|
| `bemerkung` | `Bemerkung` | (default) | `bemerkung` | `bemerkung` | ✅ OK |
| `stammdaten` | `Stammdaten` | `StammdatenItem` | `stammdaten` | `stammdaten` | ✅ OK |
| `preis` | `Preis` | `PreisItem` | `preis` | `preis` | ✅ OK |
| `leistung` | `Leistung` | `LeistungItem` | `leistung` | `leistung` | ✅ OK |
| `mitglied` | `Mitglieds` | `Mitglied` | `mitglieds` | `mitglied` | ❌ Falsch |
| `waren` | `Waren` | `WarenItem` | `waren` | `waren` | ✅ OK |
| `beitrag` | `Beitraege` | `Beitrag` | `beitraege` | `beitrag` | ❌ Falsch |
| `beitrag_status_verlauf` | `BeitragStatusVerlauf` | (default) | `beitrag_status_verlauf` | `beitrag_status_verlauf` | ✅ OK |
| `rechnung` | `Rechnungen` | `Rechnung` | `rechnungen` | `rechnung` | ❌ Falsch |
| `rechnung_position` | `RechnungPositionen` | `RechnungPosition` | `rechnung_positionen` | `rechnung_position` | ❌ Falsch |

## Lösung: `tableName`-Override + Migration

### Strategie

Die Dart-Klassennamen (`Mitglieds`, `Beitraege`, `Rechnungen`, `RechnungPositionen`) bleiben **unverändert**, da sie als Drift-Accessor (`_db.mitglieds`, `_db.beitraege`, etc.) im gesamten Projekt verwendet werden. Stattdessen wird der SQLite-Name über `@override String get tableName` korrigiert.

**Vorteile:**
- Minimaler Code-Änderungsaufwand (keine Umbenennung von ~50+ Referenzen)
- Dart-Accessors bleiben stabil (`_db.mitglieds`, `_db.beitraege`, etc.)
- SQLite-Tabellennamen werden mit structur.md konsistent
- Generierte Data-Class-Namen (`Mitglied`, `Beitrag`, `Rechnung`, `RechnungPosition`) bleiben korrekt

**Nachteil:**
- Dart-Accessor `_db.mitglieds` ≠ SQLite-Tabelle `mitglied` (kosmetisch, dokumentiert in Konvention)

### Schema-Version: 15 → 16

## Implementierungsschritte

### Schritt 1: `tableName`-Override in 4 Tabellen-Klassen hinzufügen

#### [`mitglied_table.dart`](lib/core/database/tables/mitglied_table.dart)
```dart
@DataClassName('Mitglied')
class Mitglieds extends Table {
  @override
  String get tableName => 'mitglied';
  // ... bestehende Spalten
}
```

#### [`beitraege_table.dart`](lib/core/database/tables/beitraege_table.dart)
```dart
@DataClassName('Beitrag')
class Beitraege extends Table {
  @override
  String get tableName => 'beitrag';
  // ... bestehende Spalten
}
```

#### [`rechnung_table.dart`](lib/core/database/tables/rechnung_table.dart)
```dart
@DataClassName('Rechnung')
class Rechnungen extends Table {
  @override
  String get tableName => 'rechnung';
  // ... bestehende Spalten
}
```

#### [`rechnung_position_table.dart`](lib/core/database/tables/rechnung_position_table.dart)
```dart
@DataClassName('RechnungPosition')
class RechnungPositionen extends Table {
  @override
  String get tableName => 'rechnung_position';
  // ... bestehende Spalten
}
```

### Schritt 2: Schema-Version erhöhen + Migration hinzufügen

In [`database.dart`](lib/core/database/database.dart):

```dart
@override
int get schemaVersion => 16;  // war 15
```

Neuer Migrations-Block in `onUpgrade`:

```dart
} else if (from == 15) {
  // v16: Tabellennamen an structur.md anpassen (Singular statt Plural)
  await customStatement('ALTER TABLE mitglieds RENAME TO mitglied');
  await customStatement('ALTER TABLE beitraege RENAME TO beitrag');
  await customStatement('ALTER TABLE rechnungen RENAME TO rechnung');
  await customStatement('ALTER TABLE rechnung_positionen RENAME TO rechnung_position');
}
```

> **Hinweis**: SQLite ≥ 3.25.0 aktualisiert FK-Referenzen automatisch bei `ALTER TABLE ... RENAME TO`. Das wird über `sqlite3_flutter_libs` sichergestellt.

### Schritt 3: Raw-SQL-Queries aktualisieren

Folgende Dateien enthalten hartcodierte Tabellennamen in SQL-Strings:

| Datei | Zeile | Alt | Neu |
|-------|-------|-----|-----|
| [`beitraege_repository.dart`](lib/features/beitraege/data/beitraege_repository.dart:207) | 207 | `FROM beitraege WHERE` | `FROM beitrag WHERE` |
| [`rechnungen_repository.dart`](lib/features/rechnungen/data/rechnungen_repository.dart:294) | 294 | `FROM rechnungen WHERE` | `FROM rechnung WHERE` |

### Schritt 4: CSV Import/Export prüfen

Die CSV-Services verwenden `actualTableName` (Drift-Property), die automatisch den überladenen `tableName` zurückgibt. Daher **keine Änderung nötig** an:

- [`csv_export_service.dart`](lib/core/data/csv_export_service.dart) — verwendet `tableName` Parameter
- [`csv_import_service.dart`](lib/core/data/csv_import_service.dart) — verwendet `actualTableName`
- [`csv_import_service_v2.dart`](lib/core/data/csv_import_service_v2.dart) — verwendet `actualTableName`
- [`csv_export_dialog.dart`](lib/common_widgets/csv_export_dialog.dart) — verwendet `actualTableName`

**ABER**: Die Display-Name-Mappings in den CSV-Services müssen ggf. aktualisiert werden, falls sie die alten SQL-Namen als Key verwenden.

### Schritt 5: Code-Generierung ausführen

```bash
flutter pub run build_runner build -d
```

### Schritt 6: Konvention in AGENTS.md und Rules dokumentieren

Update [`AGENTS.md`](AGENTS.md) und [`.roo/rules-code/AGENTS.md`](.roo/rules-code/AGENTS.md):

```
- **Drift table class names** use German pluralization (`Mitglieds`, `Beitraege`, `Rechnungen`, `RechnungPositionen`) 
  but **SQLite table names** use singular per structur.md (`mitglied`, `beitrag`, `rechnung`, `rechnung_position`) 
  via `tableName` override. Never change class names — only override `tableName` if needed.
```

## Dateien-Übersicht

| Datei | Aktion |
|-------|--------|
| [`lib/core/database/tables/mitglied_table.dart`](lib/core/database/tables/mitglied_table.dart) | `tableName` Override hinzufügen |
| [`lib/core/database/tables/beitraege_table.dart`](lib/core/database/tables/beitraege_table.dart) | `tableName` Override hinzufügen |
| [`lib/core/database/tables/rechnung_table.dart`](lib/core/database/tables/rechnung_table.dart) | `tableName` Override hinzufügen |
| [`lib/core/database/tables/rechnung_position_table.dart`](lib/core/database/tables/rechnung_position_table.dart) | `tableName` Override hinzufügen |
| [`lib/core/database/database.dart`](lib/core/database/database.dart) | Schema-Version 15→16, Migration hinzufügen |
| [`lib/features/beitraege/data/beitraege_repository.dart`](lib/features/beitraege/data/beitraege_repository.dart) | Raw-SQL `beitraege` → `beitrag` |
| [`lib/features/rechnungen/data/rechnungen_repository.dart`](lib/features/rechnungen/data/rechnungen_repository.dart) | Raw-SQL `rechnungen` → `rechnung` |
| [`AGENTS.md`](AGENTS.md) | Konvention dokumentieren |
| [`.roo/rules-code/AGENTS.md`](.roo/rules-code/AGENTS.md) | Konvention dokumentieren |

## Risiken

1. **Bestehende Datenbanken**: Migration muss `ALTER TABLE RENAME` korrekt ausführen. Bei Fehlern greift der Dev-Modus (DB wird neu erstellt).
2. **FK-Referenzen**: SQLite ≥ 3.25.0 aktualisiert diese automatisch. Getestet werden muss mit `PRAGMA foreign_keys = ON`.
3. **Backup-Kompatibilität**: Bestehende Backups enthalten alte Tabellennamen. Der CSV-Import verwendet `actualTableName` und sollte korrekt funktionieren.
4. **Dev-Datenbank**: Nach der Migration kann die Dev-DB manuell gelöscht und neu erstellt werden für einen sauberen Test.

## Test-Plan

1. Dev-Datenbank löschen: `rm clup_data_dev.sqlite`
2. App starten → Tabellen werden mit neuen Namen erstellt
3. In DB Browser prüfen: Tabellen heißen `mitglied`, `beitrag`, `rechnung`, `rechnung_position`
4. Bestehende Funktionalität testen: Mitglieder anlegen, Beitrag erstellen, Rechnung erstellen
5. CSV Export/Import testen
6. App mit bestehender DB (Schema 15) starten → Migration muss korrekt laufen
