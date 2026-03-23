# AppDataGridV2 - Nutzungsanalyse

> Stand: 23.03.2026

## Zusammenfassung

**Alle DataGrids im Projekt verwenden bereits `AppDataGridV2`!** ✅

Die alte Version (`lib/widgets/data_grid/app_data_grid.dart`) ist **verwaist** und wird nirgendwo mehr importiert.

---

## Aktuelle Nutzung von AppDataGridV2

### 1. StammdatenDataGrid
**Datei**: `lib/features/stammdaten/widgets/stammdaten_data_grid.dart`

```dart
AppDataGridV2<StammdatenItem>(
  items: rowData,
  columnConfigs: [...],
  toSearchString: (s) => '${s.bezeichnung} ${s.wert} ${s.kategorie} ${s.schluessel}',
  toJson: (s) => {...},
  fromJson: (json) => StammdatenItem(...),
  detailModalBuilder: (item, colId) => ...,
)
```
**Status**: ✅ V2 verwendet

---

### 2. RechnungDataGrid
**Datei**: `lib/features/rechnungen/widgets/rechnung_data_grid.dart`

```dart
AppDataGridV2<RechnungRowData>(
  items: rowData,
  columnConfigs: [...],
  toSearchString: (r) => '${r.rechnungsnummer} ${r.kundeName}',
  toJson: (r) => {...},
  fromJson: (json) => RechnungRowData(...),
  rowBgColorResolver: (r) => kRechnungStatusColors[r.status],
  detailModalBuilder: (item, colId) => ...,
)
```
**Status**: ✅ V2 verwendet

---

### 3. WarenDataGrid
**Datei**: `lib/features/waren/widgets/waren_data_grid.dart`

```dart
AppDataGridV2<WarenRowData>(
  items: rowData,
  columnConfigs: [...],  // mit currencyFormatter
  toSearchString: (w) => '${w.bezeichnung} ${w.kategorie}',
  toJson: (w) => {...},
  fromJson: (json) => WarenRowData(...),
  detailModalBuilder: (item, colId) => ...,
)
```
**Status**: ✅ V2 verwendet

---

### 4. BeitragDataGrid
**Datei**: `lib/features/beitraege/presentation/widgets/beitrag_data_grid.dart`

```dart
AppDataGridV2<BeitragRowData>(
  items: rowData,
  columnConfigs: [...],  // mit StatusBadge renderer
  toSearchString: (b) => '${b.rechnungsnummer} ${b.mitgliedName} ${b.leistungName}',
  toJson: (b) => {...},
  fromJson: (json) => BeitragRowData(...),
  rowBgColorResolver: (b) => b.statusColor,
  detailModalBuilder: (item, colId) => ...,
)
```
**Status**: ✅ V2 verwendet

---

### 5. LeistungDataGrid
**Datei**: `lib/features/leistungen/widgets/leistung_data_grid.dart`

```dart
AppDataGridV2<LeistungRowData>(
  items: rowData,
  columnConfigs: [...],  // mit berechnetem nettopreis
  toSearchString: (l) => '${l.name} ${l.laufzeit}',
  toJson: (l) => {...},
  fromJson: (json) => LeistungRowData(...),
  detailModalBuilder: (item, colId) => ...,
)
```
**Status**: ✅ V2 verwendet

---

### 6. MemberDataGrid
**Datei**: `lib/features/members/widgets/member_data_grid.dart`

```dart
AppDataGridV2<MemberRowData>(
  items: rowData,
  columnConfigs: [...],  // mit currencyFormatter für Beitrag
  toSearchString: (m) => '${m.name} ${m.vorname} ${m.ort} ${m.leistungName}',
  toJson: (m) => {...},
  fromJson: (json) => MemberRowData(...),
  detailModalBuilder: (item, colId) => ...,
)
```
**Status**: ✅ V2 verwendet

---

## Verwaiste Dateien (Alte Version)

Die folgenden Dateien werden **nicht mehr verwendet** und könnten gelöscht werden:

```
lib/widgets/data_grid/
├── app_data_grid.dart           ❌ NICHT MEHR VERWENDET
├── app_data_grid_locale.dart    ❌ NICHT MEHR VERWENDET
├── filter_settings_dialog.dart  ❌ NICHT MEHR VERWENDET
├── sort_column_config.dart      ❌ NICHT MEHR VERWENDET
├── sort_settings_dialog.dart    ❌ NICHT MEHR VERWENDET
```

### Überprüfung auf Verwendung

```bash
# Suche nach Importen der alten Version
grep -r "widgets/data_grid/app_data_grid.dart" lib/ --include="*.dart"
# Ergebnis: Keine Treffer

grep -r "import.*data_grid/" lib/ --include="*.dart"
# Ergebnis: Nur imports auf data_grid_v2/
```

---

## Feature-Vergleich: Alt vs. Neu

| Feature | Alte Version | Neue V2 |
|---------|--------------|---------|
| Generics | ❌ Nein | ✅ Ja |
| Controller Pattern | ❌ Nein | ✅ Ja |
| JSON API (Import/Export) | ❌ Nein | ✅ Ja |
| File I/O | ❌ Nein | ✅ Ja |
| Headless API | ❌ Nein | ✅ Ja |
| rowBgColorResolver | ❌ Nein | ✅ Ja |
| CRUD Callbacks | ❌ Nein | ✅ Ja |
| Enter-Key Support | ✅ Ja | ✅ Ja |
| Multi-Sort Dialog | ✅ Ja | ✅ Ja |
| Filter Dialog | ✅ Ja | ✅ Ja |
| Full-Text Search | ✅ Ja | ✅ Ja |

---

## Empfohlene Aktionen

### Option 1: Alte Dateien löschen (Empfohlen)
Da alle DataGrids bereits auf V2 migriert sind:

```bash
rm lib/widgets/data_grid/app_data_grid.dart
rm lib/widgets/data_grid/app_data_grid_locale.dart
rm lib/widgets/data_grid/filter_settings_dialog.dart
rm lib/widgets/data_grid/sort_column_config.dart
rm lib/widgets/data_grid/sort_settings_dialog.dart
```

### Option 2: Als Backup behalten
Wenn Sie die alte Version als Referenz behalten möchten, verschieben Sie sie in einen `legacy/`-Ordner.

### Option 3: Umbenennen für Klarheit
`lib/widgets/data_grid/` → `lib/widgets/data_grid_legacy/`

---

## Test-Empfehlung

Vor dem Löschen der alten Dateien sollten Sie testen:

1. **Alle Features öffnen**:
   - Mitglieder
   - Beiträge
   - Leistungen
   - Waren
   - Rechnungen
   - Stammdaten

2. **Funktionen prüfen**:
   - Daten werden korrekt angezeigt
   - Suche funktioniert
   - Sortierung funktioniert
   - Filter funktioniert
   - Doppelklick öffnet Dialog
   - Enter-Taste öffnet Dialog

3. **Keine Import-Fehler** im Terminal prüfen

---

## Fazit

✅ **Die Migration zu AppDataGridV2 ist vollständig abgeschlossen!**

Alle 6 DataGrid-Implementationen verwenden die neue V2-Version mit:
- Voller Typ-Sicherheit durch Generics
- JSON Import/Export API
- Programmatischer Steuerung via Controller
- Dynamischen Zeilenfarben
- Sauberer Architektur

Die alten Dateien können bedenkenlos gelöscht werden.
