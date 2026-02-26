---
trigger: always_on
---

# FLUTTER DESKTOP TECH STACK & GUIDELINES (Boxing Club App)

**Scope:** Gilt für den gesamten Flutter-Code in `lib/` und `test/`.

## 1. ARCHITEKTUR & APP-KONTEXT
- **[MUST] Kontext:** Die App ist ein Desktop-Verwaltungssystem (Windows/macOS/Linux) für einen Boxclub (Mitglieder, Verträge, Point-of-Sale/Verkauf).
- **[MUST] UI-Paradigma:** Optimiere strikt für Desktop (Maus & Tastatur). Nutze [NEVER] reine Mobile-Paradigmen. Nutze Sidebars (`NavigationRail` oder Split-Views), kompakte `DataTable` für Listen und unterstütze Tastatur-Shortcuts.
- **[MUST] Feature-First:** Strukturiere `lib/` nach Features (z.B. `lib/features/members`, `lib/features/pos`), nicht nach Typen (`lib/models`, `lib/views`).

## 2. DER "NO-BOILERPLATE" STACK (WICHTIG!)
- **[NEVER] Reinvent the Wheel:** Schreibe keinen Code, den ein etabliertes Package besser löst.
- **[MUST] State Management:** Nutze AUSSCHLIESSLICH `hooks_riverpod` (Riverpod V2+ mit Code-Generation `@riverpod`).
- **[NEVER] StatefulWidgets:** Schreibe [NEVER] klassische `StatefulWidget`. Nutze für lokalen State IMMER `flutter_hooks` (z.B. `useState`, `useEffect`, `useTextEditingController`). Das hält den Code extrem kurz.
- **[MUST] Data Classes:** Nutze IMMER `freezed` und `json_serializable` für Models. Schreibe [NEVER] `copyWith`, `==` Operator oder `fromJson` manuell.
- **[MUST] Routing:** Nutze `go_router` für deklaratives, typisiertes Routing.

## 3. DATENBANK (SQLite)
- **[MUST] ORM/Database:** Nutze AUSSCHLIESSLICH das `drift` Package für die SQLite-Anbindung.
- **[NEVER] Raw SQL:** Schreibe [NEVER] rohe SQL-Strings mit dem Basis-`sqflite` Package. Definiere Tabellen als Dart-Klassen (`class Members extends Table`) und lass Drift die Queries typsicher generieren.
- **[MUST] Architektur:** Kapsel alle Datenbank-Zugriffe in Riverpod-Providern (Repositories). Das UI darf [NEVER] direkt mit Drift kommunizieren.

## 4. UI & MODERN DESIGN
- **[MUST] Design System:** Nutze Material 3 (`useMaterial3: true`), aber passe das Theme für einen "Desktop-Look" an (weniger Padding, kleinere Schriften als auf Mobile).Die UI Größe muss zur besseren Lesbarkeit einstellbar und kontrstreich sein.
- **[MUST] UI-Bibliotheken:** Nutze moderne, etablierte Helfer:
  - Nutze das `gap` Package anstelle von `SizedBox(height: ...)` für Abstände.
  - Nutze `shadcn_ui` (oder ähnliche moderne Flutter-Ports), falls komplexe Desktop-Komponenten (wie moderne Dialoge, Select-Boxen) benötigt werden.
- **[MUST] DRY (Don't Repeat Yourself):** Lagere Buttons, Cards und Formular-Felder sofort in `lib/common_widgets/` aus. [NEVER] copy-paste dieselbe `TextField`-Konfiguration dreimal.
 

## 5. KI / VIBE-CODING WORKFLOW FÜR FLUTTER
- **[MUST] Code Generation Step:** Da wir `freezed`, `drift` und `riverpod_generator` nutzen, [MUST] du nach jeder Änderung an Models, Providern oder Tabellen den User auffordern: *"Bitte führe `dart run build_runner build -d` aus."* (Oder führe ihn selbst aus, falls du Terminal-Zugriff hast).
- **[MUST] Kurzer Code:** Schreibe UI-Code deklarativ und kompakt. Extrahiere komplexe Widget-Bäume in private Methoden oder kleine Hook-Widgets, um die Lesbarkeit (und den AI-Context) zu schonen.

## 6. Datenstruktur
- **[MUST] Datenstruktur ** in der Datei lib/assets/data/structur.ts werden die Schemata der Datenstruktur festgelegt. Diese Datei enthält Definitionen im JSON Format zu den Tabellen und Datenobjekten und den Relationen untereinander. Dies ist die bestimmende Quelle für Änderunge am Datenbankschema, in der Anwendungslogik und im UI. Die Konsitenz der verschiedenen Bereiche mit der Definition in lib/assets/data/structur.ts ist entscheidend.

## 7. DataGrid im UI
- **[MUST] Tabellen im UI ** beachte die Definition für die Darstellung von Daten in Tabellenform in der Datei .agent/rules/datagrid.md