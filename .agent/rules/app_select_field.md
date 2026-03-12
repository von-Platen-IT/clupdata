# AI Coding Agent — Konfiguration: AppSelectField & AppDropdownField

> **Scope:** Dieses Dokument beschreibt den aktuellen Stand des Select/Dropdown-Systems
> in diesem Flutter-Projekt und ist **bindend** für alle KI- und Entwickler-Anpassungen.
> Es ersetzt jede frühere Nutzung von Flutters eingebautem `DropdownMenu`.

---

## 1. Übersicht

Das Projekt verwendet ein vollständig **selbst implementiertes** Overlay-basiertes
Select-Widget (`AppSelectField<T>`). Es gibt **keine** Nutzung von `DropdownMenu`,
`DropdownButton` oder `Autocomplete` aus dem Flutter-SDK.

### Dateien

| Datei | Rolle |
|---|---|
| `lib/common_widgets/forms/app_select_field.dart` | Basisklasse — enthält alle Logik |
| `lib/common_widgets/forms/app_dropdown_field.dart` | Thin-Wrapper für Rückwärtskompatibilität |

---

## 2. Zwei Modi (`AppSelectMode`)

```dart
enum AppSelectMode {
  select,       // Nur gültige Listeneinträge erlaubt
  autocomplete, // Freier Text zusätzlich erlaubt
}
```

### `AppSelectMode.select` (Standard)
- Der Anwender kann tippen, um die Liste zu **filtern**.
- Beim Verlassen des Feldes (Tab / Fokus verlieren) wird der Text gegen die
  Optionsliste validiert. Kein Treffer → **vorheriger Wert wird wiederhergestellt**.
- Alle Dropdowns im Projekt verwenden diesen Modus über `AppDropdownField`.

### `AppSelectMode.autocomplete`
- Gleiche Filter-UX wie `select`.
- Beim Verlassen wird **kein** Restore durchgeführt — freier Text bleibt erhalten.
- Einsatz z.B. für große dynamische Listen (Mitgliedsuche, Produktsuche).

---

## 3. Tastaturverhalten (vollständig funktionsfähig)

| Taste | Ergebnis |
|---|---|
| **Tab** → Feld fokussieren | Overlay öffnet sich sofort |
| **↑ / ↓** | Eintrag in der Liste navigieren |
| **Enter** | Hervorgehobenen / einzigen Treffer bestätigen; Overlay schließt; **Fokus bleibt** auf Feld |
| **Tab** (Overlay offen) | Wie Enter, aber Fokus spring **natürlich weiter** zum nächsten Widget |
| **Escape** | Overlay schließt; vorheriger Wert wird wiederhergestellt |
| **Tippen** | Liste wird live gefiltert; Overlay öffnet sich falls zu |

> **Implementierungsdetail Pfeiltasten:** Ein übergeordneter
> `Focus(canRequestFocus: false, onKeyEvent: ...)` fängt Arrow-Keys ab,
> **bevor** der TextField-Cursor-Movement-Handler sie verarbeitet.
> Deshalb funktionieren ↑↓ auch nach dem Tippen zuverlässig.

---

## 4. Mausbedienung

- Klick auf einen Listeneintrag nutzt **`onTapDown`** (nicht `onTap`).
- `onTapDown` feuert beim Maustaste-**Drücken**, bevor das TextField den Fokus
  verliert. `onTap` (Loslassen) käme zu spät, weil das Overlay durch den
  Fokusverlust bereits wieder geschlossen wäre.

---

## 5. Performance (große Listen)

- **`ListView.builder`** — nur sichtbare Zeilen werden gerendert (lazy).
- **`useMemoized`** — die Filterliste wird nur neu berechnet wenn sich
  `filterText` oder `options` ändert.
- **`overlayVersion` (ValueNotifier)** — das Overlay-Widget wird über einen
  `ValueListenableBuilder` punktuell neu gebaut, ohne den gesamten Dialog
  rebuilden zu müssen.
- **Kein Debounce** für In-Memory-Listen — Filterung ist synchron schnell genug.
  Für Server-side-Search: `AppDebouncer` aus `lib/utils/app_debouncer.dart` verwenden.

---

## 6. API-Referenz

### `AppSelectField<T>` (Basisklasse)

```dart
AppSelectField<String>(
  controller: myController,     // TextEditingController — hält den bestätigten Wert
  label: 'Vertragsart',
  options: allLeistungen,       // List<T>
  getLabel: (l) => l.name,      // T → String für Anzeige und Filterung
  mode: AppSelectMode.select,   // oder .autocomplete
  required: false,              // Pflichtfeld-Stern im Label
  focusNode: myFocusNode,       // optional — für Tab-Reihenfolge im Dialog
)
```

### `AppDropdownField<T>` (Wrapper, rückwärtskompatibel)

```dart
// Identische API wie zuvor — intern delegiert an AppSelectField.select
AppDropdownField<String>(
  controller: myController,
  label: 'Status',
  options: const ['offen', 'bezahlt', 'storniert'],
  getLabel: (v) => v,
  focusNode: myFocusNode,
)
```

> **[MUST]** `AppDropdownField` ist der Standard für alle fixen Listen.
> `AppSelectField` (direkt) nur wenn `mode: AppSelectMode.autocomplete` benötigt wird.

---

## 7. Wichtige Einschränkungen

- **[NEVER]** `DropdownMenu`, `DropdownButton` oder Flutters `Autocomplete` verwenden.
- **[NEVER]** `onTap` für Overlay-Liste nutzen — immer `onTapDown`.
- **[NEVER]** `overlayVersion.value++` in einem `useEffect` aufrufen (führt zu
  *"setState called during build"* Fehler). Stattdessen direkt in den jeweiligen
  State-Change-Handlern aufrufen (openOverlay, closeOverlay, onChanged, Pfeil-Handler).
- **[MUST]** `controller.text` enthält immer den zuletzt **bestätigten** Wert.
  Während der Eingabe/Filterung weicht der angezeigte Text ab — das ist korrekt.

---

## 8. Autocomplete-Beispiel (für zukünftige Screens)

```dart
// Mitglied-Auswahl aus großer dynamischer Liste:
AppSelectField<Mitglied>(
  mode: AppSelectMode.autocomplete,
  controller: ctrlMitglied,
  label: 'Mitglied',
  options: allMitglieder,          // kann 1000+ Einträge enthalten
  getLabel: (m) => '${m.name}, ${m.vorname}',
  focusNode: fnMitglied,
)

// Nach Auswahl: ctrlMitglied.text == 'Müller, Hans'
// Rückführung auf ID in onSave:
final selected = allMitglieder
  .where((m) => '${m.name}, ${m.vorname}' == ctrlMitglied.text)
  .firstOrNull;
final mitgliedId = selected?.id;
```

---

*Stand: 2026-03-12 — Version 1.0*
*Gilt für: alle Formulare in `lib/features/*/presentation/dialogs/` und `lib/features/*/widgets/`*
