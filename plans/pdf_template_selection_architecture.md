# Architektur: PDF Template-Auswahl mit Live-Preview

## Zusammenfassung

Erweiterung des PDF-Export-Systems um eine interaktive Template-Auswahl im Preview-Dialog mit automatischer PDF-Regeneration bei Template-Wechsel.

---

## Anforderungen

1. **Template-Dropdown im Preview-Dialog**
   - Dropdown mit allen verfügbaren Vorlagen
   - Sofortige Aktualisierung des Previews bei Auswahl

2. **Kontext-sensitive Filterung**
   - Nur passende Vorlagen anzeigen (Liste vs. Detail)
   - Rechnungs-spezifische Vorlagen nur bei Rechnungen

3. **Deutsche Anzeigenamen**
   - Bereits vorhanden via `displayName` im `PdfTemplate`-Interface

---

## Architektur-Änderungen

### 1. Neue/Geänderte Komponenten

```
lib/widgets/data_grid_v2/export/pdf/
├── pdf_preview_dialog.dart           # ← StatefulWidget mit Template-Auswahl
├── pdf_template_selector.dart        # ← NEU: Dropdown-Komponente
├── pdf_preview_controller.dart       # ← NEU: State-Management für Preview
└── ... (bestehende Dateien)
```

### 2. PdfPreviewDialog wird Stateful

**Bisher (Stateless):**
```dart
class PdfPreviewDialog extends StatelessWidget {
  final Uint8List pdfData;
  final String title;
  // ...
}
```

**Neu (Stateful):**
```dart
class PdfPreviewDialog extends StatefulWidget {
  final ExportDataTable dataTable;     // ← Rohdaten statt PDF
  final PdfExportContext context;       // ← Export-Kontext
  final bool isDetailView;              // ← Für Filterung
  final String? entityType;             // ← "rechnung", "mitglied", etc.
  
  @override
  State<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<PdfPreviewDialog> {
  PdfTemplate? _selectedTemplate;
  Uint8List? _pdfData;
  bool _isGenerating = false;
  
  @override
  void initState() {
    super.initState();
    _selectedTemplate = _getDefaultTemplate();
    _generatePdf();
  }
  
  Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);
    
    final pdf = await _selectedTemplate!.generate(
      widget.dataTable,
      widget.context,
    );
    
    setState(() {
      _pdfData = await pdf.save();
      _isGenerating = false;
    });
  }
  
  void _onTemplateChanged(PdfTemplate? template) {
    if (template == null || template == _selectedTemplate) return;
    
    setState(() {
      _selectedTemplate = template;
    });
    _generatePdf();
  }
}
```

### 3. PdfTemplateSelector-Komponente

```dart
/// Dropdown zur Auswahl einer PDF-Vorlage.
/// 
/// Filtert Vorlagen basierend auf dem Export-Kontext (Liste vs. Detail)
/// und optional dem Entitätstyp.
class PdfTemplateSelector extends StatelessWidget {
  /// Aktuell ausgewählte Vorlage
  final PdfTemplate? selectedTemplate;
  
  /// Callback bei Auswahländerung
  final ValueChanged<PdfTemplate?> onChanged;
  
  /// Ob der Export im Detail-Modus ist
  final bool isDetailView;
  
  /// Optional: Entitätstyp für spezifische Filterung
  final String? entityType;
  
  const PdfTemplateSelector({
    super.key,
    required this.selectedTemplate,
    required this.onChanged,
    required this.isDetailView,
    this.entityType,
  });

  @override
  Widget build(BuildContext context) {
    final templates = _getFilteredTemplates();
    
    return DropdownButtonFormField<PdfTemplate>(
      value: selectedTemplate,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Vorlage',
        prefixIcon: Icon(Icons.style_outlined),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: templates.map((template) {
        return DropdownMenuItem<PdfTemplate>(
          value: template,
          child: Text(template.displayName),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
  
  /// Filtert Vorlagen basierend auf Kontext
  List<PdfTemplate> _getFilteredTemplates() {
    var templates = PdfTemplateRegistry.all;
    
    // Filter 1: Detail-View Kompatibilität
    if (isDetailView) {
      templates = templates.where((t) => t.supportsDetailView).toList();
    }
    
    // Filter 2: Entitätsspezifische Vorlagen (optional)
    if (entityType != null) {
      // Priorisiere entitätsspezifische Vorlagen
      final specificTemplates = templates.where((t) => 
        _isTemplateForEntity(t, entityType!)
      ).toList();
      
      if (specificTemplates.isNotEmpty) {
        // Kombiniere: Spezifische zuerst, dann generische
        final genericTemplates = templates.where((t) => 
          !_isTemplateForEntity(t, entityType!)
        ).toList();
        return [...specificTemplates, ...genericTemplates];
      }
    }
    
    return templates;
  }
  
  bool _isTemplateForEntity(PdfTemplate template, String entityType) {
    // Prüfung basierend auf Template-Typ oder Namen
    final name = template.displayName.toLowerCase();
    return name.contains(entityType.toLowerCase());
  }
}
```

### 4. Template-Kategorien (Erweiterung)

Neue Properties im `PdfTemplate`-Interface:

```dart
abstract class PdfTemplate {
  String get displayName;
  bool get supportsDetailView;
  
  /// NEU: Template-Kategorie für bessere Organisation
  PdfTemplateCategory get category;
  
  /// NEU: Optional: Für welche Entitäten geeignet
  List<String>? get supportedEntityTypes;
  
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  );
}

enum PdfTemplateCategory {
  /// Generische Tabellen-Layouts
  generic,
  
  /// Rechnungs- und Finanzdokumente
  invoice,
  
  /// Mitglieder-Dokumente
  member,
  
  /// Listen und Übersichten
  list,
  
  /// Detail-Ansichten
  detail,
}
```

### 5. PdfExporter Anpassung

Der `PdfExporter` gibt jetzt Rohdaten zurück statt fertiges PDF:

```dart
class PdfExportResult {
  final ExportDataTable dataTable;
  final PdfExportContext context;
  final bool isDetailView;
  final String? entityType;
  
  PdfExportResult({
    required this.dataTable,
    required this.context,
    required this.isDetailView,
    this.entityType,
  });
}

class PdfExporter {
  // Bisher: exportList() gab Uint8List zurück
  // Neu: Gibt Daten zurück für Template-Auswahl im Dialog
  
  PdfExportResult prepareExport(
    DataGridController<dynamic> controller, {
    required String title,
    String? entityName,
    bool visibleOnly = true,
  }) {
    final dataTable = controller.toExportDataTable(
      title: title,
      visibleOnly: visibleOnly,
    );
    
    return PdfExportResult(
      dataTable: dataTable,
      context: PdfExportContext(
        title: title,
        exportTimestamp: DateTime.now(),
        activeFilters: controller.activeFilters,
        activeSorts: controller.sortConfigs,
        isDetailView: false,
        entityName: entityName,
      ),
      isDetailView: false,
      entityType: _detectEntityType(entityName),
    );
  }
  
  String? _detectEntityType(String? entityName) {
    if (entityName == null) return null;
    final lower = entityName.toLowerCase();
    if (lower.contains('rechnung')) return 'rechnung';
    if (lower.contains('mitglied')) return 'mitglied';
    if (lower.contains('beitrag')) return 'beitrag';
    return null;
  }
}
```

### 6. Neue Export-Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ BENUTZER KLICKT "PDF ERSTELLEN/DRUCKEN"                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. PdfExporter.prepareExport()                                               │
│    - ExportDataTable erstellen                                               │
│    - PdfExportContext erstellen                                              │
│    - Entitätstyp erkennen                                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. PdfPreviewDialog öffnen (mit Daten, nicht PDF)                            │
│    - StatefulWidget mit Template-Auswahl                                     │
│    - Standard-Template vorab generieren                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. Template-Auswahl (Dropdown)                                               │
│    - Gefilterte Liste basierend auf isDetailView + entityType                │
│    - Deutsche Namen aus displayName                                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 4. Live-Regeneration bei Template-Wechsel                                    │
│    - PDF neu generieren                                                      │
│    - Loading-Indicator anzeigen                                              │
│    - Preview aktualisieren                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. Benutzer drückt "Drucken" oder "Speichern"                                │
│    - Aktuelles PDF wird verwendet                                            │
│    - Druckdialog oder Speicherdialog öffnet sich                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## UI-Mockup

```
┌──────────────────────────────────────────────────────────────────────┐
│  📄 PDF Vorschau                                        [X]          │
├──────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Vorlage:  [Einfache Tabelle ▼]                                 │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  Mitgliederliste                                             │    │
│  │  Filter: Status: Aktiv                                       │    │
│  │                                                              │    │
│  │  ┌─────────────┬───────────┬────────┐                       │    │
│  │  │ Name        │ Vorname   │ Status │                       │    │
│  │  ├─────────────┼───────────┼────────┤                       │    │
│  │  │ Müller      │ Hans      │ Aktiv  │                       │    │
│  │  │ Schmidt     │ Anna      │ Aktiv  │                       │    │
│  │  └─────────────┴───────────┴────────┘                       │    │
│  │                                                              │    │
│  │  Seite 1/3                                                   │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  [Drucken]  [Speichern]  [Teilen]                                    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Implementierungsschritte

### Phase 1: Core-Änderungen
1. [`PdfTemplate`](lib/widgets/data_grid_v2/export/pdf/pdf_template.dart:1) erweitern mit `category` und `supportedEntityTypes`
2. [`PdfTemplateRegistry`](lib/widgets/data_grid_v2/export/pdf/pdf_template_registry.dart:1) erweitern mit Filter-Methoden
3. [`PdfExporter`](lib/widgets/data_grid_v2/export/pdf/pdf_exporter.dart:1) neue `prepareExport()`-Methode

### Phase 2: UI-Komponenten
1. [`PdfTemplateSelector`](lib/widgets/data_grid_v2/export/pdf/pdf_template_selector.dart:1) neu erstellen
2. [`PdfPreviewDialog`](lib/widgets/data_grid_v2/export/pdf/pdf_preview_dialog.dart:1) zu StatefulWidget umwandeln
3. Integration von Template-Dropdown im Dialog-Header

### Phase 3: Integration
1. [`PdfExportMenuItem`](lib/widgets/data_grid_v2/export/pdf/pdf_export_menu_item.dart:1) anpassen für neuen Workflow
2. Bestehende Templates mit Kategorien und EntityTypes versehen
3. Testing und Fehlerbehebung

### Phase 4: Dokumentation
1. Anleitung aktualisieren mit Template-Auswahl
2. Code-Beispiele für neue Features
3. Best Practices dokumentieren

---

## Code-Beispiel: Erweiterte Vorlage

```dart
class InvoicePdfTemplate implements PdfTemplate {
  @override
  String get displayName => 'Rechnungs-Layout';

  @override
  bool get supportsDetailView => true;
  
  @override
  PdfTemplateCategory get category => PdfTemplateCategory.invoice;
  
  @override
  List<String> get supportedEntityTypes => ['rechnung', 'angebot'];

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    // ... bestehende Implementierung
  }
}
```

---

## Vorteile der neuen Architektur

| Vorteil | Beschreibung |
|---------|--------------|
| **Intuitiv** | Benutzer sieht sofort das Ergebnis der gewählten Vorlage |
| **Kontext-sensitiv** | Nur relevante Vorlagen werden angezeigt |
| **Flexibel** | Keine separate "Druck-Vorlage" nötig |
| **Wiederverwendbar** | Template-Logik bleibt unverändert |
| **Erweiterbar** | Neue Filterkriterien einfach hinzufügbar |

---

*Architektur-Dokument erstellt für PDF Template-Auswahl Feature*
