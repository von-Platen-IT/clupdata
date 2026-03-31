# Redesign: PDF Export Menu mit Kontext-Erkennung

## Problem-Analyse

### Aktuelles Verhalten / Problem
- Das alte globale Export-Menü ("Exportieren > PDF erstellen") war zu weit vom Kontext der Ansichten entfernt.
- Es konnte nicht nativ feststellen, ob eine Liste oder ein Detail-Dialog aktiv ist.
- Drucken war fehleranfällig, wenn unklar war, welcher DataGridController aktiv ist.
- Globale Provider für lokale Kontexte (wie `ExportContextNotifier`) führten zu Spaghetti-Code und unerwartetem Verhalten.

### Gewünschtes Verhalten (Neues Konzept)
1. **Kontext durch UI-Nähe**: Statt intelligenter globaler Erkennung bekommt jede Ansicht (Grid und Dialog) ihre eigenen Export-Buttons unmittelbar da, wo sie gebraucht werden.
2. **Flexible Export-Optionen**: Im Dialog kann weiterhin gewählt werden zwischen:
   - Aktuelle Ansicht (sichtbare Spalten)
   - Alle Details (alle verfügbaren Felder)
   - Kompletter Export (alle Daten der Entität)
3. **Intelligente Menü-Anzeige**: Das Menü passt sich dem aktuellen Kontext an

---

## Architektur-Plan

### 1. Abschaffung von globalem Context-State

Statt eines globalen `ExportContextNotifier` werden Export-Informationen über `ExportConfig` und `ExportContextData` rein als gekapselte Daten-Objekte direkt in den lokalen Dropdown-Buttons instanziiert und weitergegeben.
  
`VpitDataGrid` nimmt z.B. eine `exportConfig` entgegen. Wenn sie nicht null ist, wird ein lokaler `ListExportMenuButton` in der Navbar des Grids angezeigt. Dieser Button hat direkten Zugriff auf den dort ohnehin existierenden `DataGridController`.

Die Dialoge (`AppEditDialogScaffold`) nutzen analog einen `DialogExportMenuButton`, der per Consumer auf den Provider des DataGrids der darunterliegenden Liste zugreift.

### 2. Erweitertes Export-Menü

### 2. Lokale Export-Menüs (Toolbar & Dialog)

Statt eines Menüpunkts oben im OS-Frame, enthalten Tabellen und Dialoge die Auswahl direkt in der Toolbar bzw. Title-Zeile:

```
[Icon] / Dropdown
├── 📄 Als PDF exportieren...
│   └── [Öffnet Preview-Dialog / ExportOptionsDialog]
│
├── 🖨️ Drucken...
│   └── [Direkter OS-Druckdialog oder Print Preview]
│
├── ───────────────
│
└── 📊 CSV exportieren...
```

### 3. Export-Modi

| Modus | Beschreibung | Verwendung |
|-------|--------------|------------|
| **Aktuelle Ansicht** | Exportiert nur die im Grid sichtbaren Spalten | Schneller Überblick |
| **Alle Details** | Exportiert alle verfügbaren Felder der Entität | Vollständige Info |
| **Mit Relationen** | Inklusive verknüpfter Daten (Beiträge, Rechnungen) | Kompletter Datensatz |

### 4. Daten-Strategien

#### Für Listen-Export
```dart
// Option 1: Nur sichtbare Spalten (default)
controller.toExportDataTable(visibleOnly: true)

// Option 2: Alle verfügbaren Spalten
controller.toExportDataTable(visibleOnly: false)

// Option 3: Alle Felder der Domain-Modelle
// Benötigt: Repository-Zugriff für vollständige Daten
```

#### Für Detail-Export
```dart
// Hole alle Details aus dem Repository
final fullData = await repository.getFullDetails(item.id);

// Erstelle erweiterte Export-Tabelle
final dataTable = ExportDataTable(
  headers: ['Feld', 'Wert'],
  rows: fullData.toLabelValuePairs(),
);
```

### 5. UI-Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Benutzer klickt "PDF erstellen" im Menü                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Kontext prüfen:                                              │
│    - Ist ein Detail-Dialog geöffnet?                            │
│    - Welcher Entity-Type?                                       │
│    - Welcher Export-Modus ist gewählt?                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Daten zusammenstellen:                                       │
│    - Bei Liste: Aus DataGridController                          │
│    - Bei Detail: Aus Repository mit allen Feldern               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Preview-Dialog mit Template-Auswahl öffnen                   │
│    - Gefilterte Vorlagen basierend auf Kontext                  │
│    - Live-Regeneration bei Template-Wechsel                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Benutzer wählt:                                              │
│    - Template                                                   │
│    - Drucken / Speichern / Teilen                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementierungs-Phasen

### Phase 1: Kontext-Erkennung
- [ ] ExportContext Provider erstellen
- [ ] In alle Edit-Dialoge integrieren
- [ ] MainMenuBar anpassen für Kontext-Prüfung

### Phase 2: Erweiterte Export-Optionen
- [ ] ExportOptionsDialog erstellen
- [ ] Optionen: Aktuelle Ansicht / Alle Details / Komplett
- [ ] Integration in das Menü

### Phase 3: Vollständiger Detail-Export
- [ ] Repository-Methoden für vollständige Daten
- [ ] DetailExportService für Label-Value-Paare
- [ ] Integration mit Relationen (lazy loading)

### Phase 4: UI/UX-Optimierung
- [ ] Visuelle Hinweise im Menü (Badge für Detail-Modus)
- [ ] Tooltipps mit Erklärungen
- [ ] Keyboard-Shortcuts

---

## Code-Struktur

```
lib/
├── core/
│   └── providers/
│       └── export_context_provider.dart      # NEU
├── features/
│   └── export/                               # NEU
│       ├── data/
│       │   └── detail_export_service.dart    # Vollständige Daten holen
│       ├── presentation/
│       │   ├── export_options_dialog.dart    # Export-Modus wählen
│       │   └── export_menu_controller.dart   # Menü-Logik
│       └── domain/
│           └── export_options.dart           # ExportMode Enum
└── widgets/data_grid_v2/export/pdf/
    ├── pdf_exporter.dart                     # ERWEITERT
    └── pdf_preview_dialog.dart               # ERWEITERT
```

---

## User Stories

### Als Anwender möchte ich...

1. **...eine einzelne Rechnung drucken**
   - Öffne Rechnungs-Detail
   - Klicke "Exportieren > PDF erstellen"
   - Wähle "Rechnungs-Layout"
   - Drucke

2. ...alle Mitgliederdaten exportieren**
   - Öffne Mitglieder-Liste
   - Klicke "Exportieren > Export-Optionen > Alle Details"
   - Wähle "Kompakte Tabelle"
   - Speichere als PDF

3. ...einen Beitrag mit allen Details drucken**
   - Öffne Beitrags-Detail
   - Klicke "Exportieren > PDF erstellen"
   - System erkennt automatisch Detail-Kontext
   - Alle verfügbaren Felder werden exportiert

---

*Dokument erstellt für PDF Export Redesign v1.0*
