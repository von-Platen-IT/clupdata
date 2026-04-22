# AGENTS.md

This file provides guidance to agents when working in **Code** mode.

## Code Mode - Non-Obvious Rules

### Formatierung (Projekt-spezifisch)
- **Einrückung**: 2 Leerzeichen (nicht 4!)
- **Zeilenlänge**: 100 Zeichen
- **Trailing Commas**: Immer bei mehrzeiligen Strukturen

### Import-Reihenfolge (STRIKT)
```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/database/database.dart';
import '../models/member_row_data.dart';
```

### Naming Conventions
| Element | Konvention | Beispiel |
|---------|------------|----------|
| Konstanten | lowerCamelCase | `defaultPageSize` |
| Enum-Werte | lowerCamelCase | `paymentStatusOpen` |
| Private Members | _prefix | `_internalCache` |

### Riverpod Patterns
- `@riverpod` für Provider (nicht StateProvider)
- `ref.invalidate()` für Neuladen bei nächster Verwendung
- `await ref.refresh()` für sofortiges Neuladen
- `@Riverpod(keepAlive: true)` für globale Daten (z.B. [`appDatabaseProvider`](lib/core/providers/database_provider.dart:11))

### Drift Patterns
- Tabellen mit Constraints definieren
- Transactions für mehrere Operationen
- NIE String-Interpolation in SQL
- Tabellen in `lib/core/database/tables/` - jede Tabelle eigene Datei: `{entity}_table.dart`

### Widget Patterns
- `ConsumerWidget` für einfache Fälle
- `HookConsumerWidget` für Controller/Animationen
- `StatefulWidget` vermeiden - Hooks verwenden
- Dialoge: [`AppEditDialogScaffold`](lib/common_widgets/app_edit_dialog_scaffold.dart:35) aus `common_widgets/` verwenden
- Löschen: [`AppDialogDeleteAction`](lib/common_widgets/app_dialog_delete_action.dart:8) mit built-in confirmation

### Dialoge
- `AppEditDialogScaffold` verwendet `CallbackShortcuts` für ESC/Enter
- Enter triggert Save nur wenn kein Multi-line Textfield oder Dropdown fokussiert
- Export-Button wird nur bei `exportConfig != null` angezeigt

### Code-Generierung
- `flutter pub run build_runner build -d` nach Änderungen an `@riverpod`, `@DriftDatabase`, `@freezed`
- Generierte Dateien (*.g.dart) nie manuell bearbeiten
- Hot Reload funktioniert NICHT für generierten Code - App neu starten!

### Repository Pattern
- Repositories in `features/<name>/data/<name>_repository.dart`
- Repository enthält NUR Klasse + `@riverpod` Provider
- Domain-Modelle in `features/<name>/domain/models/`
- UI-Provider in `features/<name>/presentation/providers/`
- **Bemerkung-Operationen zentralisiert** in [`lib/core/data/bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart:1)

### Status-Historie Pattern
- Jeder Status-Wechsel bei `beitrag` MUSS in `beitrag_status_verlauf` protokolliert werden
- Bemerkung ist **Pflichtfeld** (NOT NULL)
- [`BeitraegeRepository.updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) erkennt Status-Änderung automatisch
- `_addStatusEintrag()` ist private - nie direkt aus UI aufrufen

### Rechnugsnummer-Generierung
- Format: `RE-YYYY-XXXXX` (Jahr + 5-stellige Nummer)
- [`BeitraegeRepository.generateRechnungsnummer()`](lib/features/beitraege/data/beitraege_repository.dart:199) prüft auf Eindeutigkeit

### Export-Architektur Split
- Feature-spezifisch: `lib/features/export/`
- Generisch wiederverwendbar: `lib/widgets/data_grid_v2/export/`
