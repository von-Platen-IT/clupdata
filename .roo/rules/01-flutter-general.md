# Flutter/Dart Allgemeine Regeln

## Projekt-Kontext

Dies ist eine **Flutter Desktop-Anwendung** (Windows/Linux/macOS) für Vereinsverwaltung mit folgenden Kernmerkmalen:

- **State Management**: Riverpod (hooks_riverpod) mit Code-Generation
- **Datenbank**: Drift (SQLite) für lokale Datenspeicherung
- **Routing**: go_router für deklaratives Routing
- **UI-Komponenten**: Pluto Grid für Data Grids, Material Design 3
- **Architektur**: Feature-basierte Clean Architecture

## Kritische Regeln

### 1. Single Source of Truth (SSOT)

**Die Datei [`lib/assets/data/structur.md`](lib/assets/data/structur.md:1) ist die zentrale Spezifikation.**

- Jede Änderung an Datenbanktabellen, Relationen oder UI-Screens MUSS zuerst hier dokumentiert werden
- Prüfe vor jeder Änderung, welche Bereiche des Projekts davon betroffen sind
- Halte die Dokumentation synchron mit der Implementierung

### 2. Keine Destruktiven Operationen

- **NIE** `rm -rf`, `DROP TABLE`, oder andere Daten-löschende Befehle ausführen
- Datenbankmigrationen immer über Drift Migrationen durchführen
- Backup-Strategie beachten (siehe `pfad_backup` in Stammdaten)

### 3. Keine ungefragten Dependencies

- Neue Packages nur nach expliziter Rücksprache hinzufügen
- Priorisiere Packages, die bereits im Projekt verwendet werden
- Prüfe vorher: Ist das Package notwendig oder lässt sich das Problem mit bestehenden Tools lösen?

## Code-Qualitätsstandards

### SOLID-Prinzipien

1. **Single Responsibility**: Eine Klasse hat genau eine Aufgabe
2. **Open/Closed**: Offen für Erweiterungen, geschlossen für Modifikationen
3. **Liskov Substitution**: Subtypen verhalten sich wie Basistypen
4. **Interface Segregation**: Spezifische Interfaces bevorzugen
5. **Dependency Inversion**: Abhängigkeiten gegen Abstraktionen, nicht konkrete Implementierungen

### Komposition vor Vererbung

```dart
// ✅ RICHTIG: Komposition nutzen
class MemberDataGrid extends StatelessWidget {
  final MemberRepository repository;
  
  const MemberDataGrid({required this.repository});
}

// ❌ FALSCH: Tiefe Vererbung
class MemberDataGrid extends BaseDataGrid<Member> {
  // Vermeiden!
}
```

### Immutability

```dart
// ✅ RICHTIG: Unveränderliche State-Klassen
@freezed
class MemberState with _$MemberState {
  const factory MemberState({
    required List<Member> members,
    required bool isLoading,
  }) = _MemberState;
}

// ❌ FALSCH: Mutable State
class MemberState {
  List<Member> members = []; // Vermeiden!
}
```

## Performance-Richtlinien

### 1. Lazy Loading

- Data Grids laden Daten paginiert
- Repositories bieten Stream-basierte Updates
- Bilder nur bei Bedarf laden

### 2. Widget-Optimierung

```dart
// ✅ RICHTIG: const Konstruktoren verwenden
const SizedBox(height: 16)

// ✅ RICHTIG: Riverpod select für spezifische Updates
final name = ref.watch(memberProvider.select((m) => m.name));

// ❌ FALSCH: Übermäßige Rebuilds
ref.watch(memberProvider); // Nur wenn alle Daten benötigt werden
```

### 3. Datenbank-Performance

- Indizes für häufig abgefragte Felder (siehe structur.md Kapitel 2)
- Batch-Operationen für Massenupdates
- Streams nur wenn nötig, sonst Future

## UI/UX Standards

### 1. Deutsche Lokalisierung

- Alle Benutzeroberflächen auf Deutsch
- Datumsformat: `dd.MM.yyyy`
- Zahlenformat: Deutsche Konvention (1.234,56)
- Währung: €-Symbol nach dem Betrag (123,45 €)

### 2. Status-Farben (VERBINDLICH)

| Status | Farbe | Hex |
|--------|-------|-----|
| `kontiert` | Hellgelb | `#FFF9C4` |
| `offen` | Hellorange | `#FFE0B2` |
| `bezahlt` | Hellgrün | `#C8E6C9` |
| `angemahnt` | Hellrot | `#FFCDD2` |
| `storniert` | Hellgrau | `#EEEEEE` |
| `inkasso` | Pink | `#F8BBD0` |

- Zentrale Quelle: `lib/features/beitraege/utils/beitrag_status_colors.dart`
- NIEMALS Hex-Werte hardcoden

### 3. Konsistente Formularfelder

- Verwende [`app_text_field.dart`](lib/common_widgets/forms/app_text_field.dart:1), [`app_date_picker_field.dart`](lib/common_widgets/forms/app_date_picker_field.dart:1), [`app_dropdown_field.dart`](lib/common_widgets/forms/app_dropdown_field.dart:1)
- Einheitliche Validierungsmuster
- ReadOnly-Felder optisch als solche erkennbar

## Sicherheit

### 1. SQL-Injection-Schutz

- NIE String-Interpolation in SQL-Queries
- Drift's Type-Safe API verwenden
- Alle User-Inputs validieren

### 2. Datenschutz

- Personenbezogene Daten (Mitgliederdaten) sensibel behandeln
- Keine Daten in Logs ausgeben (außer IDs)
- Backup-Verzeichnis sicher konfigurieren

## Dev-Server Hinweis

- Starte KEINE Entwicklungsserver (`flutter run` im Dauermodus) selbstständig
- Der Entwickler übernimmt das Builden und Testen
- Code-Generierung (`build_runner`) nur auf Anfrage

## Wichtige Dateien

| Datei | Zweck |
|-------|-------|
| [`lib/assets/data/structur.md`](lib/assets/data/structur.md:1) | Datenstruktur-Spezifikation |
| [`lib/core/database/database.dart`](lib/core/database/database.dart:1) | Drift-Datenbank-Setup |
| [`lib/core/router/app_router.dart`](lib/core/router/app_router.dart:1) | Go-Router-Konfiguration |
| [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart:1) | Material 3 Theme |
