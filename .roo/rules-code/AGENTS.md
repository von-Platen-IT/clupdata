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

### Drift Patterns
- Tabellen mit Constraints definieren
- Transactions für mehrere Operationen
- NIE String-Interpolation in SQL

### Widget Patterns
- `ConsumerWidget` für einfache Fälle
- `HookConsumerWidget` für Controller/Animationen
- `StatefulWidget` vermeiden - Hooks verwenden

### Dialoge
- `AppEditDialogScaffold` aus `common_widgets/` verwenden
- `AppDialogDeleteAction` für Löschbestätigungen

### Code-Generierung
- `flutter pub run build_runner build -d` nach Änderungen an `@riverpod`, `@DriftDatabase`, `@freezed`
- Generierte Dateien (*.g.dart) nie manuell bearbeiten
