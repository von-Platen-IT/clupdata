# Plan: Performance-Optimierung für ClupData

> **Status**: Entwurf
> **Erstellt**: 2026-10-13
> **Quellen**: Offizielle Flutter-Dokumentation (docs.flutter.dev, Stand Flutter 3.47):
> [Performance best practices](https://docs.flutter.dev/perf/best-practices),
> [Improving rendering performance](https://docs.flutter.dev/perf/rendering-performance),
> [Performance](https://docs.flutter.dev/perf)
> **Kontext**: Flutter-Linux-Desktop, Drift/SQLite (Singleton über Isolate-Override),
> **Riverpod** (Code-Gen – nicht das klassische `provider`-Paket; die Selektions-
> Muster gelten analog über `ref.watch(select(...))`), Kursplan-Dialoge,
> Schnellerfassung, GSettings-Integration.

---

## 0. Kernprinzipien der offiziellen Doku (Kurzfassung)

| Prinzip | Quelle |
|---|---|
| Möglichst viele `const`-Konstruktoren – Flutter kann den Rebuild abschneiden | Best practices |
| Große Kinderlisten nie direkt bauen (`Column(children: [for …])`) – immer Builder nutzen | Rendering performance |
| `build()`-Kosten kontrollieren – teure Operationen (Formatierung, Suche, Berechnung) aus dem Build heraushalten | Best practices |
| Listen/Grids durchdacht implementieren (Lazy-Loading) | Best practices |
| Layout-Pässe durch Intrinsic-Operationen minimieren | Best practices |
| Opacity/Clipping sparsam nutzen (verursacht `saveLayer`) | Best practices |
| Frames in 16 ms bauen (60 fps) – Profiling mit DevTools im `--profile`-Modus | Best practices |
| Impeller ist der Standard-Renderer (auf dem Linux-Desktop via OpenGL-ES) | Rendering performance |

---

## 1. UI-Performance (Widget-Rebuilds & Rendering)

### 1.1 Lazy-Listen statt statischer Kinderlisten (HÖCHSTER IMPACT)

**Problem:** `Column(children: [for (final x in liste) …])` oder `ListView(children: …)`
bauen **alle** Elemente sofort – bei 200 erfassten Mitgliedern oder langen
Vorschau-Listen entstehen hunderte RenderObjects pro Frame.

**Lösung:** `ListView.builder` baut nur die sichtbaren Zeilen (Lazy-Loading).

```dart
// ❌ Vorher: alles gleichzeitig im Baum
ListView(children: [for (final n in protokoll.namen) Text(n)]);

// ✅ Nachher: nur sichtbare Zeilen werden gebaut
ListView.builder(
  itemCount: protokoll.namen.length,
  itemBuilder: (context, i) => Text(protokoll.namen[i]),
);
```

**Erwartung:** Konstanter Frame-Aufwand (≈ 16 ms) unabhängig von der Listenlänge;
Speicherverbrauch sinkt drastisch bei > 50 Einträgen.

**Projekt-Betroffenheit:** [`erfasste_liste.dart`](../lib/features/schnellerfassung/presentation/widgets/erfasste_liste.dart),
[`kurs_list_dialog.dart`](../lib/features/calendar/presentation/dialogs/kurs_list_dialog.dart),
[`kursplan_list_dialog.dart`](../lib/features/calendar/presentation/dialogs/kursplan_list_dialog.dart),
[`schritt_vorschau.dart`](../lib/features/rechnungserstellung/presentation/steps/schritt_vorschau.dart) (Column + for – größter Hebel!),
[`mitglied_auswahl.dart`](../lib/features/rechnungserstellung/presentation/steps/mitglied_auswahl.dart)

### 1.2 `const`-Konstruktoren konsequent einsetzen

**Problem:** Nicht-`const`-Widgets werden bei jedem Eltern-Rebuild neu konstruiert
und verglichen; `const` erlaubt Flutter die Identitäts-Wiederverwendung.

```dart
// ❌
Text('Keine Kurse', style: theme.textTheme.bodySmall)
// ✅ – statische Teile als const
const Icon(Icons.calendar_month)
const Gap(12)
```

**Erwartung:** Weniger Allokationen pro Frame; „kostenlose" Rebuild-Vermeidung
(der Widget-Tree wird bei gleicher Konstante übersprungen).

### 1.3 RepaintBoundary für das Wochen-Raster

**Problem:** [`KursplanWochenGrid`](../lib/features/calendar/presentation/widgets/kursplan_wochen_grid.dart)
besteht aus LayoutBuilder + Stack + vielen Positioned-Blöcken – ein Repaint
(bei Hover/Scroll/Overlay) zeichnet die gesamte Spalten-Matrix neu.

**Lösung:** `RepaintBoundary` isoliert die Paint-Phase des Rasters.

```dart
RepaintBoundary(
  child: KursplanWochenGrid(termine: termine, wochenAnfang: woche),
)
```

**Erwartung:** Bei Overlays (Dialoge) und Hover-Effekten wird nur noch die
betroffene Region neu gezeichnet – spürbar flüssiger auf schwacher VM-Grafik.

### 1.4 Rebuild-Vermeidung durch Widget-Granularität

**Problem:** Große `build()`-Methoden (Screen mit Formular + Seitenleiste)
rebuilden alles, wenn sich ein kleiner Teil ändert (z. B. Zählerstand).

**Lösung:** State so weit wie möglich nach unten ziehen (eigene Widgets pro
Bereich), `select`-Muster (siehe Kap. 2), teure Operationen
(`DateFormat.format`, Berechnungen) mit `useMemoized` kapseln.

**Projekt-Betroffenheit:** [`schnellerfassung_screen.dart`](../lib/features/schnellerfassung/presentation/schnellerfassung_screen.dart)
(Duplikat-Check bereits debounce-optimiert ✓).

---

## 2. State-Management (Riverpod – Selektion statt Voll-Beobachtung)

> **Hinweis:** Das Projekt nutzt **Riverpod 3** (Code-Gen), nicht das klassische
> `provider`-Paket. Die Prinzipien sind identisch: Statt `context.select` wird
> `ref.watch(provider.select(...))` verwendet.

**Problem:** `ref.watch(ganzerProvider)` löst bei **jeder** Änderung des
Zustands einen Rebuild aus – auch wenn das Widget nur ein einziges Feld nutzt.

**Lösung:** Selektives Watchen:

```dart
// ❌ Rebuild bei jeder Änderung des Config-Objekts
final config = ref.watch(backupConfigProvider);

// ✅ Rebuild nur, wenn sich das konkrete Feld ändert
final intervall = ref.watch(
  backupConfigProvider.select((c) => c.valueOrNull?.intervallTage),
);
```

**Weitere Muster (Riverpod-Äquivalente):**

| Klassischer Provider | Riverpod im Projekt | Wirkung |
|---|---|---|
| `Selector` | `ref.watch(p.select((x) => x.feld))` | Rebuild nur bei Feld-Änderung |
| `Consumer` (Teilbaum) | Eigenes `ConsumerWidget` für den Bereich | Kleinerer Rebuild-Baum |
| Granulare Notifier | Mehrere kleine `@riverpod`-Provider statt einer großen Klasse | Feinere Abhängigkeiten |

**Erwartung:** Rebuilds sinken bei Formular-Screens mit vielen Feldern
(Schnellerfassung) und Status-Cards (Backup) spürbar.

---

## 3. Datenbank-Performance (SQLite/Drift)

### 3.1 Bereits vorhanden (keine Maßnahme nötig)

| Mechanismus | Status im Projekt |
|---|---|
| **WAL-Modus** | ✅ Aktiv (Checkpoint vor Backups, siehe [`database.dart`](../lib/core/database/database.dart:50)) |
| **Indizes** | ✅ Umfassend definiert (SSOT [`structur.md`](../lib/assets/data/structur.md:292)) |
| **Prepared Statements** | ✅ Drift nutzt automatisch gebundene Parameter (keine String-Interpolation!) |
| **Transaktionen** | ✅ Atomare Batch-Erstellung ([`abrechnung_service.dart`](../lib/features/rechnungserstellung/services/abrechnung_service.dart:166)), [`saveKursplan`](../lib/features/calendar/data/kursplan_repository.dart:96) |
| **DB-Zugriff aus Isolate** | ✅ `NativeDatabase.createInBackground` – UI wird nie blockiert |
| **Isolate-sicheres sqlite3-Loading** | ✅ `isolateSetup` ([`sqlite_loader.dart`](../lib/core/utils/sqlite_loader.dart:16)) |

### 3.2 Suchanfragen entzerren (Debounce)

**Problem:** Die Mitglieder-Suche ([`mitglied_auswahl.dart`](../lib/features/rechnungserstellung/presentation/steps/mitglied_auswahl.dart),
[`mitglied_vorlage_dialog.dart`](../lib/features/schnellerfassung/presentation/widgets/mitglied_vorlage_dialog.dart))
feuert bei **jeder Tastatureingabe** eine DB-Abfrage (20 Tasten = 20 Queries).

**Lösung:** Debounce (250–400 ms) – Muster existiert bereits im
[SchnellerfassungScreen](../lib/features/schnellerfassung/presentation/schnellerfassung_screen.dart:36)
(Duplikat-Warnung, 500 ms) und wird jetzt verallgemeinert.

**Erwartung:** ~90 % weniger DB-Abfragen beim Tippen; UI bleibt reaktiv.

### 3.3 Paging für große Datenmengen (ausstehend – zukünftig)

**Problem:** `select(...).get()` lädt bei > 10.000 Datensätzen alles in den RAM.

**Lösung:** Drift-`limit()`/`offset()` für Listen-Screens (DataGrid nutzt bereits
Paging-Konzepte). Im aktuellen Umfang (Vereinsgröße) **noch nicht nötig** –
als Reserve dokumentiert.

---

## 4. Desktop-spezifische Aspekte (Linux)

| Thema | Befund im Projekt | Maßnahme |
|---|---|---|
| **Rendering-Backend** | Impeller (OpenGL-ES) aktiv – Best Practice der Doku ✅ | Keine |
| **GLib/GSettings** | Schema-Override nötig ([`tools/gsettings_override/`](../tools/gsettings_override)) – einmalig gelöst | Keine |
| **Fenster-Resize** | Wochen-Raster nutzt `LayoutBuilder` (rekalkuliert bei Resize) – korrekt | `RepaintBoundary` (1.3) reduziert zusätzlich den Paint-Aufwand |
| **High-DPI-Text** | Flutter rendert Text per Skia/Impeller nativ scharf; `theme.textTheme`-Styles konsistent | Keine |
| **Plugin-Overhead** | `window_manager`, `file_picker` – nur bei Bedarf initialisiert ✅ | Keine |
| **Desktop-I/O** | DB + Datei-IO laufen asynchron (keine UI-Blockade) ✅ | Keine |
| **Profiling** | VM-Service + DevTools verfügbar (siehe Start-Log) | Empfehlung: `flutter run --profile -d linux` + DevTools-Timeline für Baseline-Messungen |

---

## 5. Priorisierte Umsetzung (Impact vs. Aufwand)

| # | Maßnahme | Impact | Aufwand | Betroffene Dateien | Status |
|---|---|---|---|---|---|
| 1 | `ListView.builder` statt statischer Listen | ⭐⭐⭐⭐⭐ | gering | [`erfasste_liste.dart`](../lib/features/schnellerfassung/presentation/widgets/erfasste_liste.dart), [`kurs_list_dialog.dart`](../lib/features/calendar/presentation/dialogs/kurs_list_dialog.dart), [`kursplan_list_dialog.dart`](../lib/features/calendar/presentation/dialogs/kursplan_list_dialog.dart) | umzusetzen |
| 2 | Vorschau-Liste auf Builder umstellen (größte Liste) | ⭐⭐⭐⭐⭐ | mittel | [`schritt_vorschau.dart`](../lib/features/rechnungserstellung/presentation/steps/schritt_vorschau.dart) | umzusetzen |
| 3 | Such-Debounce (Mitglieder-Suche) | ⭐⭐⭐⭐ | gering | [`mitglied_auswahl.dart`](../lib/features/rechnungserstellung/presentation/steps/mitglied_auswahl.dart), [`mitglied_vorlage_dialog.dart`](../lib/features/schnellerfassung/presentation/widgets/mitglied_vorlage_dialog.dart) | umzusetzen |
| 4 | `RepaintBoundary` Wochen-Raster | ⭐⭐⭐ | gering | [`kursplan_wochen_grid.dart`](../lib/features/calendar/presentation/widgets/kursplan_wochen_grid.dart) | umzusetzen |
| 5 | `const`-Konstruktoren vervollständigen | ⭐⭐⭐ | gering (automatisierbar) | projektweit | umzusetzen |
| 6 | Selektives `ref.watch(select(...))` | ⭐⭐⭐ | mittel | [`backup_status_card.dart`](../lib/features/backup/presentation/widgets/backup_status_card.dart) u. a. | ausgewählte Stellen |
| 7 | Paging für Listen (Zukunft) | ⭐⭐ | hoch | DataGrid-Layer | Reserve |

---

## 6. Profiling-Workflow (zur Verifikation)

```bash
# 1. Performance-Modus starten (kein Debug-Overhead)
cd /home/bernd/workprojects/clupdata
GSETTINGS_SCHEMA_DIR=tools/gsettings_override flutter run -d linux --profile

# 2. DevTools öffnen (URL erscheint im Terminal) → Reiter „Performance"
# 3. Frames während Scrollen im Kursplan / langer Vorschau beobachten
#    Ziel: grüne Frames (≤ 16 ms), keine roten Layout-Spitzen
```

Erwartete Effekte nach Umsetzung: konstante Frames bei langen Listen,
flüssigeres Öffnen der Verwaltungsdialoge, spürbar schnelleres Tippen
in der Schnellerfassung.
