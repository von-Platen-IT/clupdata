# Plan: Keyboard-Shortcuts für das Hauptmenü

## Ziel
Tastenkürzel für das Hauptmenü implementieren, um schnellen Zugriff auf wichtige Funktionen zu ermöglichen.

## Analyse der bestehenden Codebasis

Das Projekt verwendet bereits `CallbackShortcuts` (siehe [`app_edit_dialog_scaffold.dart`](lib/common_widgets/app_edit_dialog_scaffold.dart:69)):

```dart
CallbackShortcuts(
  bindings: {
    const SingleActivator(LogicalKeyboardKey.escape): () { ... },
    const SingleActivator(LogicalKeyboardKey.enter): () { ... },
  },
  child: Focus(...)
)
```

## Vorgeschlagene Architektur

### 1. Zentrale Shortcut-Definition

Eine Datei `lib/core/keyboard/keyboard_shortcuts.dart` mit:

- **Enum** für alle verfügbaren Shortcuts
- **Map** von `SingleActivator` zu Callback-Funktionen
- **Provider** für globalen Zugriff

### 2. Vorgeschlagene Shortcuts

| Funktion | Shortcut | Mnemonik |
|----------|----------|----------|
| **Datei > Einstellungen** | `Ctrl + ,` | Komma = Settings (Standard) |
| **Datei > Beenden** | `Ctrl + Q` | Q = Quit |
| **Erstellen** (dynamisch) | `Ctrl + N` | N = Neu |
| **Datenübertragung > Backup** | `Ctrl + B` | B = Backup |
| **Datenübertragung > Restore** | `Ctrl + R` | R = Restore |
| **Datenübertragung > CSV Exportieren** | `Ctrl + E` | E = Export |
| **Datenübertragung > CSV Importieren** | `Ctrl + I` | I = Import |
| **Hilfe > Hilfe & Dokumentation** | `F1` | Standard Hilfe-Taste |
| **Navigation: Dashboard** | `Alt + 1` | Erster Tab |
| **Navigation: Mitglieder** | `Alt + 2` | Zweiter Tab |
| **Navigation: Beiträge** | `Alt + 3` | Dritter Tab |
| **Navigation: Waren** | `Alt + 4` | Vierter Tab |
| **Navigation: Rechnungen** | `Alt + 5` | Fünfter Tab |

### 3. Implementierungsstrategie

#### Option A: Globaler Shortcut-Handler (empfohlen)

Den `CallbackShortcuts` Widget in [`lib/common_widgets/app_shell.dart`](lib/common_widgets/app_shell.dart:1) oder der Root-Widget-Struktur platzieren:

```dart
// In AppShell oder MainLayout
CallbackShortcuts(
  bindings: {
    // Datei-Menü
    const SingleActivator(LogicalKeyboardKey.comma, control: true): 
        () => context.push('/settings'),
    const SingleActivator(LogicalKeyboardKey.keyQ, control: true): 
        () => exit(0),
    
    // Datenübertragung
    const SingleActivator(LogicalKeyboardKey.keyB, control: true): 
        () => showBackupDialog(context, ref),
    const SingleActivator(LogicalKeyboardKey.keyR, control: true): 
        () => showRestoreDialog(context, ref),
    const SingleActivator(LogicalKeyboardKey.keyE, control: true): 
        () => showCsvBulkExportDialog(context, ref),
    const SingleActivator(LogicalKeyboardKey.keyI, control: true): 
        () => showCsvBulkImportDialog(context, ref),
    
    // Navigation (Alt + Zahl)
    const SingleActivator(LogicalKeyboardKey.digit1, alt: true): 
        () => context.go('/'),
    const SingleActivator(LogicalKeyboardKey.digit2, alt: true): 
        () => context.go('/members'),
    // ... usw.
  },
  child: Focus(
    autofocus: true,
    child: Scaffold(...),
  ),
)
```

#### Option B: Menü-spezifische Shortcuts

Alternative: Shortcuts nur aktivieren, wenn das Menü geöffnet ist (weniger praktisch für Desktop).

### 4. Visuelle Anzeige

Die Shortcuts sollten im Menü angezeigt werden:

```dart
PopupMenuItem(
  child: Row(
    children: [
      const Text('Einstellungen'),
      const Spacer(),
      Text(
        'Ctrl + ,',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    ],
  ),
),
```

### 5. Plattform-Unterschiede

| Plattform | Modifier-Key |
|-----------|-------------|
| Windows/Linux | `Ctrl` |
| macOS | `Meta` (⌘ Command) |

Implementierung mit conditional:

```dart
bool get isMacOS => Platform.isMacOS;

final modifier = isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

SingleActivator(LogicalKeyboardKey.comma, meta: isMacOS, control: !isMacOS)
```

### 6. Konflikt-Verwaltung

- Dialoge haben Vorrang (bereits implementiert in `AppEditDialogScaffold`)
- Input-Felder unterdrücken globale Shortcuts wenn fokussiert
- Menü-Shortcuts nur aktiv wenn kein Dialog geöffnet

## Implementierungsschritte

1. **Neue Datei erstellen**: `lib/core/keyboard/keyboard_shortcuts.dart`
   - Enum mit allen Shortcuts
   - Helper-Funktion für plattform-spezifische Modifier
   - Provider für globalen Zugriff

2. **AppShell anpassen**: `lib/common_widgets/app_shell.dart`
   - `CallbackShortcuts` Widget hinzufügen
   - Bindings aus der neuen Datei importieren

3. **Menü-Items aktualisieren**: `lib/common_widgets/main_menu_bar.dart`
   - Shortcut-Anzeige zu jedem Menüpunkt hinzufügen
   - Mnemonics (Unterstrichene Buchstaben) für Alt-Navigation

4. **Tests schreiben**:
   - Unit-Tests für Shortcut-Provider
   - Widget-Tests für Tastatureingaben

## Akzeptanzkriterien

- [ ] Alle vorgeschlagenen Shortcuts funktionieren
- [ ] Shortcuts werden im Menü angezeigt
- [ ] Plattform-spezifische Modifier (Ctrl/⌘) werden korrekt behandelt
- [ ] Keine Konflikte mit bestehenden Dialog-Shortcuts
- [ ] `flutter analyze` zeigt keine Fehler

## Nicht-Ziele

- Keine benutzerdefinierbaren Shortcuts (außerhalb des Scopes)
- Keine Shortcut-Hilfe-Overlay (kann später hinzugefügt werden)
