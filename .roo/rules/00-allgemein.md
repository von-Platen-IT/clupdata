# Allgemeine Projektregeln (alle Modes)

## Kommunikation
- Antworte immer auf Deutsch, es sei denn, Code-Kommentare sind betroffen
- Fasse Änderungen am Ende jeder Aufgabe kurz zusammen
- Bei Unklarheiten: Stelle genau eine Rückfrage, bevor du fortfährst

## Git-Workflow
- Schreibe keine git-Commits ohne explizite Aufforderung
- Schlage Commit-Messages nach Conventional Commits vor:
  `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`

## Dateioperation-Regeln
- Lese immer zuerst eine Datei vollständig, bevor du sie bearbeitest
- Erstelle keine Dateien außerhalb des Projektstamms
- Lösche keine Dateien ohne explizite Bestätigung

## Qualitätssicherung
- Führe nach Code-Änderungen immer `flutter analyze` aus
- Schlage bei jeder Implementierung passende Tests vor
- Weise auf Breaking Changes ausdrücklich hin

## Projekt-Kontext
- **Projektname**: ClupData – Boxing Club Management System
- **Framework**: Flutter Desktop (Windows/Linux/macOS)
- **Dart SDK**: ^3.11.0
- **State Management**: Riverpod (hooks_riverpod ^3.3.1) mit Code-Generation
- **Datenbank**: Drift (^2.31.0) für SQLite
- **Routing**: go_router (^17.1.0)
- **Data Grid**: Pluto Grid (^8.0.0)
- **Architektur**: Feature-basierte Clean Architecture

## Single Source of Truth
- **[`lib/assets/data/structur.md`](lib/assets/data/structur.md)** ist die zentrale Spezifikation
- Jede Änderung an Datenbanktabellen, Relationen oder UI-Screens MUSS zuerst hier dokumentiert werden
- Schema-Version ist aktuell **17**

## Code-Generierung (MANDATORISCH)
Nach Änderungen an `@riverpod`, `@DriftDatabase`, `@freezed`, oder `@JsonSerializable`:
```bash
flutter pub run build_runner build -d
```
**Hot Reload funktioniert NICHT für generierten Code** – App neu starten!

## Sicherheit
- **NIEMALS** String-Interpolation in SQL-Queries
- **NIEMALS** destruktive Befehle (`rm -rf`, `DROP TABLE`)
- Keine personenbezogenen Daten in Logs (nur IDs)
- Neue Packages nur nach expliziter Rücksprache

## Recherche mit Context7 (MCP) – MANDATORISCH
Bei Fragen zu Bibliotheken, Frameworks, SDKs oder CLI-Werkzeugen (Riverpod, Drift, Pluto Grid,
go_router, Dart, Flutter …) **nicht aus dem Gedächtnis antworten**, sondern die aktuelle Doku holen.
Ein Aufruf des Werkzeugs `use_mcp_tool` erfolgt immer in zwei Schritten:

1. Library-ID auflösen:
   ```json
   {"server_name":"context7","tool_name":"resolve-library-id",
    "arguments":{"libraryName":"riverpod","query":"Notifier provider code generation"}}
   ```
2. Doku abfragen (mit der ID aus Schritt 1, Format `/org/projekt`):
   ```json
   {"server_name":"context7","tool_name":"query-docs",
    "arguments":{"libraryId":"/websites/riverpod_dev","query":"Wie definiere ich einen @riverpod Notifier?","language":"de"}}
   ```

- **Kein Vorwissen als Ersatz:** erst Context7 fragen, dann planen/implementieren.
- **Kein zweiter Suchweg:** Websuche (`tavily-search`) nur, wenn Context7 keine passende
  Bibliothek findet – nicht zusätzlich.
- Ist `use_mcp_tool` im Werkzeugkasten **nicht** vorhanden, ist nicht der Server defekt, sondern
  dem Mode fehlt die Gruppe `mcp` in `.roomodes` (`groups: [..., mcp]`). Diesen Hinweis dann
  nennen, statt die Recherche stillschweigend auszulassen.
