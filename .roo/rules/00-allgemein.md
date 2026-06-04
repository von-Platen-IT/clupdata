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
