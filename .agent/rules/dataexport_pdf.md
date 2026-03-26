## **description: AI Agent Ruleset for PDF Export and Template System trigger: "*pdf*, print, template, export_pdf"**

# **SYSTEM DIRECTIVE: PDF EXPORT & TEMPLATE SYSTEM**

[CONTEXT]
You are an expert Flutter AI coding assistant. Whenever the user requests PDF generation, printing, or custom document layouts, you MUST adhere strictly to the following architectural rules.

**IMPORTANT**: This ruleset EXTENDS and references `.agent/rules/dataexport.md`. All general export principles (Single Source of Truth, Generic Abstraction, ExportDataTable contract) defined there remain fully valid. This document only adds PDF-specific extensions.

---

## **1. CORE PRINCIPLES (Inherited from dataexport.md)**

*   **[MUST] Single Source of Truth:** All PDF generation MUST source data from the `DataGridController<T>`. Never query the database directly for PDF exports.
*   **[MUST] Generic Abstraction:** The core `PdfExporter` MUST NOT depend on specific domain models. It operates on `ExportDataTable`.
*   **[MUST] ExportDataTable Contract:** The PDF system consumes `ExportDataTable` with `List<String> headers` and `List<List<dynamic>> rows` as defined in `dataexport.md` Section 2.1.

---

## **2. PDF TEMPLATE ARCHITECTURE**

### **2.1 Template Interface**

All PDF layouts MUST implement the `PdfTemplate` interface:

```dart
abstract class PdfTemplate {
  /// Generates the PDF document structure
  /// [dataTable] contains the generic data from DataGridController
  /// [context] provides export context (title, timestamp, filters applied, etc.)
  Future<pw.Document> generate(ExportDataTable dataTable, PdfExportContext context);
  
  /// Returns the template name for UI display
  String get displayName;
  
  /// Returns true if this template supports detail view (single item export)
  bool get supportsDetailView;
}

class PdfExportContext {
  final String title;
  final DateTime exportTimestamp;
  final Map<String, String>? activeFilters;
  final List<SortColumnConfig>? activeSorts;
  final bool isDetailView;
  final String? entityName; // e.g., 'Mitglied', 'Rechnung'
  
  PdfExportContext({
    required this.title,
    required this.exportTimestamp,
    this.activeFilters,
    this.activeSorts,
    this.isDetailView = false,
    this.entityName,
  });
}
```

### **2.2 Two-Mode System**

| Mode | Template Class | Use Case |
|------|---------------|----------|
| **Simple** | `SimpleTableTemplate` | Quick list exports without decoration. Automatic table generation from `ExportDataTable`. |
| **Template-based** | Domain-specific implementations (e.g., `InvoicePdfTemplate`) | Custom layouts with logos, headers, footers, signatures. Domain-specific formatting. |

### **2.3 Simple Mode (Default)**

The `SimpleTableTemplate` MUST provide:

*   Clean table layout with headers
*   Automatic pagination for long tables
*   Alternating row colors for readability
*   Footer with page numbers and export timestamp
*   NO decoration, NO logos - pure data presentation

```dart
class SimpleTableTemplate implements PdfTemplate {
  @override
  String get displayName => 'Einfache Tabelle';
  
  @override
  bool get supportsDetailView => true;
  
  @override
  Future<pw.Document> generate(ExportDataTable dataTable, PdfExportContext context) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        header: (format) => _buildHeader(context),
        footer: (format) => _buildFooter(context, format),
        build: (context) => [
          pw.Table.fromTextArray(
            headers: dataTable.headers,
            data: dataTable.rows.map((r) => r.map((v) => v.toString()).toList()).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
      ),
    );
    
    return pdf;
  }
}
```

### **2.4 Template-Based Mode**

Domain-specific templates MUST:

*   Extend/implement `PdfTemplate`
*   Access additional data via `getDetailJson` or `JsonPayload` from controller if needed
*   Include headers (logos, addresses), footers (page numbers, legal text) as required
*   Apply domain-specific formatting (currency, dates per `dataexport.md` Section 2.2)

```dart
class InvoicePdfTemplate implements PdfTemplate {
  @override
  String get displayName => 'Rechnungs-Layout';
  
  @override
  bool get supportsDetailView => true; // Only makes sense for single invoice
  
  @override
  Future<pw.Document> generate(ExportDataTable dataTable, PdfExportContext context) async {
    // Only process if detail view
    if (!context.isDetailView) {
      throw UnsupportedError('Invoice template requires detail view');
    }
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pwContext) => pw.Column(
          children: [
            _buildLetterhead(), // Logo, address
            pw.SizedBox(height: 20),
            _buildInvoiceHeader(context), // Invoice number, date
            pw.SizedBox(height: 20),
            _buildPositionsTable(dataTable), // Items
            pw.SizedBox(height: 20),
            _buildTotals(), // Totals calculation
            pw.Spacer(),
            _buildFooter(), // Legal text, bank details
          ],
        ),
      ),
    );
    
    return pdf;
  }
}
```

---

## **3. TEMPLATE REGISTRATION & SELECTION**

### **3.1 Template Registry**

Templates MUST be registered in a central registry:

```dart
class PdfTemplateRegistry {
  static final Map<String, PdfTemplate> _templates = {};
  
  static void register(String key, PdfTemplate template) {
    _templates[key] = template;
  }
  
  static PdfTemplate get(String key) => _templates[key] ?? SimpleTableTemplate();
  static List<PdfTemplate> get all => _templates.values.toList();
  
  // Predefined templates
  static PdfTemplate get simple => _templates['simple'] ?? SimpleTableTemplate();
}
```

### **3.2 Registration Pattern**

Register templates in feature modules:

```dart
// In features/rechnungen/rechnungen_feature.dart or similar
void registerRechnungTemplates() {
  PdfTemplateRegistry.register('invoice', InvoicePdfTemplate());
  PdfTemplateRegistry.register('invoice_reminder', InvoiceReminderTemplate());
}
```

### **3.3 Template Selection Logic**

The UI MUST:

*   Show `SimpleTableTemplate` as default option
*   Show domain-specific templates if available for current context
*   Filter templates by `supportsDetailView` when in detail modal context

---

## **4. PDF GENERATOR IMPLEMENTATION**

### **4.1 PdfExporter Class**

```dart
class PdfExporter {
  final PdfTemplate template;
  
  PdfExporter({PdfTemplate? template}) 
      : template = template ?? SimpleTableTemplate();
  
  /// Exports the current grid view to PDF
  Future<Uint8List> exportList<T>(
    DataGridController<T> controller, {
    required String title,
  }) async {
    final dataTable = _toExportDataTable(controller);
    final context = PdfExportContext(
      title: title,
      exportTimestamp: DateTime.now(),
      activeFilters: controller.activeFilters,
      activeSorts: controller.sortConfigs,
      isDetailView: false,
    );
    
    final document = await template.generate(dataTable, context);
    return document.save();
  }
  
  /// Exports a single detail item to PDF
  Future<Uint8List> exportDetail<T>(
    DataGridController<T> controller,
    T item, {
    required String title,
    String? entityName,
  }) async {
    final dataTable = _itemToExportDataTable(controller, item);
    final context = PdfExportContext(
      title: title,
      exportTimestamp: DateTime.now(),
      isDetailView: true,
      entityName: entityName,
    );
    
    final document = await template.generate(dataTable, context);
    return document.save();
  }
  
  ExportDataTable _toExportDataTable<T>(DataGridController<T> controller) {
    // Implementation per dataexport.md Section 2.1
    // Uses DataGridColumnConfig.valueExtractor and formatter
  }
  
  ExportDataTable _itemToExportDataTable<T>(DataGridController<T> controller, T item) {
    // Converts single item to ExportDataTable (label-value pairs)
  }
}
```

### **4.2 Required Packages**

```yaml
dependencies:
  pdf: ^3.10.0          # PDF generation
  printing: ^5.12.0     # Print preview and native print dialog
```

---

## **5. UI INTEGRATION (Global Export Menu)**

Per `dataexport.md` Section 4, PDF export MUST be integrated into the global "Exportieren" menu:

### **5.1 Menu Structure**

```
Exportieren
├── Drucken...          → PrintPreviewDialog with template selection
├── PDF erstellen...    → Save PDF to file (with template selection)
├── CSV erstellen...    → Per dataexport.md
└── Excel erstellen...  → Per dataexport.md
```

### **5.2 Context Detection**

The menu MUST detect context per `dataexport.md` Section 4.1:

*   **No modal open**: Export `filteredSortedItems` from active `DataGridController` using List templates
*   **Detail modal open**: Export the single item using Detail-capable templates only

### **5.3 Print Preview Dialog**

MUST implement a preview dialog:

```dart
class PdfPreviewDialog extends StatelessWidget {
  final Uint8List pdfData;
  final String title;
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: PdfPreview(
        build: (format) => pdfData,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false, // Fixed to A4 for consistency
      ),
    );
  }
}
```

---

## **6. FORMATTING & LOCALIZATION**

Per `dataexport.md` Section 2.2 and `projekt_rules.md` Section 6:

*   **[MUST]** Apply `DataGridColumnConfig.formatter` before passing to `ExportDataTable`
*   **[MUST]** Use German locale (de_DE) for all date and number formatting
*   **[MUST]** Date format: `dd.MM.yyyy`
*   **[MUST]** Currency format: `123,45 €` (symbol after amount)
*   **[MUST]** Use `intl` package NumberFormat and DateFormat

---

## **7. FILE NAMING CONVENTIONS**

```
lib/
└── widgets/
    └── data_grid_v2/
        └── export/
            ├── export_data_table.dart      # DTO (from dataexport.md)
            ├── pdf/
            │   ├── pdf_exporter.dart       # Main exporter class
            │   ├── pdf_template.dart       # Template interface
            │   ├── simple_table_template.dart
            │   └── template_registry.dart
            └── templates/                   # Domain-specific templates
                ├── invoice_pdf_template.dart
                └── member_list_pdf_template.dart
```

---

## **8. REQUIRED AI CHECKLIST (Verify before generating code)**

* [ ] Template implements `PdfTemplate` interface
* [ ] Template uses `ExportDataTable` and `PdfExportContext` as input
* [ ] Data sourced from `DataGridController` (not direct DB queries)
* [ ] `SimpleTableTemplate` provides clean, paginated table output
* [ ] Domain templates include proper headers/footers per requirements
* [ ] Formatters from `DataGridColumnConfig` are applied
* [ ] German localization (dates, numbers, currency) is correct
* [ ] Template registered in `PdfTemplateRegistry`
* [ ] Integration in global "Exportieren" menu (not grid toolbar)
* [ ] Context detection (List vs Detail) implemented correctly
* [ ] Print preview dialog implemented
* [ ] PDF uses A4 format consistently

---

## **9. REFERENCE TO BASE RULES**

For all aspects not explicitly covered here, refer to:

| Topic | Reference File |
|-------|----------------|
| General Export Architecture | `.agent/rules/dataexport.md` |
| DataGrid Controller API | `.agent/rules/datagrid.md` |
| Flutter/Dart Standards | `.agent/rules/projekt_rules.md` |
| Tech Stack | `.agent/rules/tech-stack.md` |
| Data Structure | `lib/assets/data/structur.md` |

---

*This ruleset extends dataexport.md and MUST be applied together with it.*
