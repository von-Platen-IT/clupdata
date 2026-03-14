# CLupData Agent Konfiguration

Diese Datei definiert die Agent-Modi und Spezialisierungen für die RooCode-Konfiguration dieses Flutter-Projekts.

## Verfügbare Modi

### 1. 🏗️ Architect Mode (`architect`)

**Zweck**: Architektur-Planung, Design-Entscheidungen, Systemstruktur

**Wann verwenden**:
- Neue Features planen
- Datenbank-Schema-Änderungen
- Architektur-Refactorings
- Komplexe UI-Strukturen entwerfen

**Regel-Dateien**:
- `.roo/rules/01-flutter-general.md`
- `.roo/rules-architect/01-flutter-arch.md`

**Spezialisierungen**:
- Datenbank-Design (Drift/Tables)
- Feature-Struktur
- State-Management-Architektur
- API/Repository-Design

**Einschränkungen**:
- Keine Dateien ändern außer `\.md$`
- Konzentration auf Design-Dokumentation

---

### 2. 💻 Code Mode (`code`)

**Zweck**: Implementierung von Features, Bugfixes, Refactoring

**Wann verwenden**:
- Neue Features implementieren
- Bugs beheben
- Tests schreiben
- Code-Generierung ausführen

**Regel-Dateien**:
- `.roo/rules/01-flutter-general.md`
- `.roo/rules-code/01-dart-style.md`

**Spezialisierungen**:
- Dart/Flutter Widgets
- Riverpod Provider
- Drift Repositories
- UI-Komponenten

**Einschränkungen**:
- Keine Markdown-Dokumentation
- Keine Projekt-weite Architektur-Änderungen ohne Rücksprache

---

### 3. ❓ Ask Mode (`ask`)

**Zweck**: Fragen beantworten, Code erklären, Dokumentation erstellen

**Wann verwenden**:
- Code erklären lassen
- Best Practices erfragen
- Dokumentation schreiben
- Technische Konzepte klären

**Regel-Dateien**:
- `.roo/rules/01-flutter-general.md`

**Spezialisierungen**:
- Code-Review
- Dokumentation
- Erklärungen
- Troubleshooting-Hinweise

---

### 4. 🪲 Debug Mode (`debug`)

**Zweck**: Fehler suchen, Logs analysieren, Probleme diagnostizieren

**Wann verwenden**:
- Exceptions debuggen
- Performance-Probleme analysieren
- Memory-Leaks finden
- UI-Rendering-Probleme

**Regel-Dateien**:
- `.roo/rules/01-flutter-general.md`
- `.roo/rules-code/01-dart-style.md`

**Spezialisierungen**:
- Stack-Trace-Analyse
- Logging hinzufügen
- Flutter Inspector
- Riverpod DevTools

---

## Projekt-Kontext

### Tech Stack

```yaml
Framework: Flutter 3.x (Desktop: Windows/Linux/macOS)
State Management: Riverpod (hooks_riverpod) + Code Generation
Database: Drift (SQLite)
Routing: go_router
UI Components: Material 3, Pluto Grid
Localization: de_DE
```

### Projektstruktur

```
lib/
├── core/               # Shared Kernel (Database, Router, Theme)
├── common_widgets/     # Wiederverwendbare UI-Komponenten
├── features/           # Feature-Module
│   ├── members/
│   ├── beitraege/
│   ├── leistungen/
│   ├── waren/
│   ├── rechnungen/
│   └── stammdaten/
└── main.dart
```

### Wichtige Dateien

| Datei | Zweck |
|-------|-------|
| `lib/assets/data/structur.md` | Single Source of Truth - Datenstruktur |
| `lib/core/database/database.dart` | Drift Database Setup |
| `lib/core/router/app_router.dart` | go_router Konfiguration |
| `lib/core/theme/app_theme.dart` | Material 3 Theme |

---

## Mode-Switching Guidelines

### Ablauf bei neuem Feature

1. **Architect Mode**: Feature planen, Datenbank-Schema definieren
2. **Code Mode**: Implementierung durchführen
3. **Ask Mode**: Dokumentation erstellen
4. **Debug Mode**: Testen und Fehler beheben

### Schnellwahl

| Situation | Empfohlener Mode |
|-----------|------------------|
| "Wie soll ich X implementieren?" | architect |
| "Implementiere X" | code |
| "Erkläre mir X" | ask |
| "Warum funktioniert X nicht?" | debug |
| "Erstelle einen Plan für X" | architect |
| "Refactore X" | code |
| "Dokumentiere X" | ask |

---

## Spezielle Anweisungen für kimik2.5

### Kontextfenster-Optimierung

- **Structur.md immer beachten**: Prüfe vor Änderungen an Datenbank/UI
- **Kompakte Prompts**: Vermeide überflüssigen Kontext
- **Inkrementelle Änderungen**: Bei großen Features in Teilschritten

### Flutter-Spezifische Hinweise

1. **Code-Generierung**: Nach Änderungen an `@riverpod`, `@freezed`, `@DriftDatabase` muss `build_runner` laufen
2. **Hot Reload**: Funktioniert nicht bei generiertem Code - Neustart nötig
3. **Desktop-Constraints**: Fenster-Größe und Tastatur-Navigation beachten

### Performance-Bewusstsein

- Widgets als `const` markieren wo möglich
- `select` für Riverpod-Provider verwenden
- Streams nur wenn nötig
- Lazy Loading in Data Grids

---

## Kommunikations-Muster

### Prompt-Struktur

```
[Ziel] + [Kontext] + [Einschränkungen]

Beispiel:
"Füge eine neue Spalte 'geburtsdatum' zur Mitglied-Tabelle hinzu.
Siehe structur.md Abschnitt 1.5 für das aktuelle Schema.
Verwende DateTimeColumn und füge einen Index hinzu."
```

### Rückfragen

Bei Unklarheiten:
1. Annahmen dokumentieren
2. Alternativen aufzeigen
3. Empfehlung geben
4. Auf Bestätigung warten

---

## Workflow-Integration

### Mit structur.md arbeiten

```
1. structur.md lesen
2. Änderungen planen
3. structur.md aktualisieren (wenn nötig)
4. Code implementieren
5. Validieren gegen structur.md
```

### Mit Git arbeiten

- Keine `git` Befehle ausführen
- Änderungen lokal vorhalten
- Der Entwickler übernimmt Versionierung

### Mit IDE arbeiten

- Keinen Dev-Server starten
- Keine `flutter run` Befehle
- Code-Generierung nur auf Anfrage
