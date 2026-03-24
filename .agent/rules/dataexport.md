## **description: AI Agent Ruleset for Data Export and Analytics implementations trigger: "*export*, print, pdf, chart, analytics, csv"**

# **SYSTEM DIRECTIVE: DATA EXPORT & ANALYTICS EXTENSION**

[CONTEXT]
You are an expert Flutter AI coding assistant. Whenever the user requests functionality to print data, export lists (PDF, CSV, Excel), or generate analytical charts/diagrams from a tabular grid, you MUST adhere strictly to the following architectural, OOP, and implementation rules.
This library acts as a generic extension to `VpitDataGrid` and `DataGridController`.

## **1. CORE PRINCIPLES & ARCHITECTURE**

*   **[MUST] Single Source of Truth:** All export and chart functions MUST source their data exclusively from the `DataGridController<T>`. Never write standalone database queries for UI data exports.
*   **[MUST] Generic Abstraction:** Export functions and chart builders MUST NOT depend on specific domain models (like `Mitglied` or `Rechnung`). They MUST accept the generic type `T` and operate on the metadata provided by `DataGridColumnConfig<T>`.
*   **[MUST] Strict Separation of Concerns:**
    *   **Data Source:** `DataGridController` (provides raw or filtered/sorted data objects).
    *   **Adapter/Transformer:** Converts `List<T>` into a generic `ExportDataTable` (resolving values via `valueExtractor`).
    *   **Output/Generator:** Concrete Exporter (e.g., `PdfExporter`, `CsvExporter`, `ChartBuilder`) that consumes `ExportDataTable`.

## **2. THE EXPORT DATA TRANSFER OBJECT (DTO)**

### **2.1 `ExportDataTable` Contract**

*   **[MUST]** Create a generic bridging class `ExportDataTable` that all concrete output generators consume.
*   **[MUST]** It MUST contain:
    *   `List<String> headers`: The titles of the columns (extracted from `DataGridColumnConfig.title`).
    *   `List<List<dynamic>> rows`: The extracted values for each row, perfectly matching the header order.
    *   *Optional:* Configuration for summary rows (e.g., column totals computed via reduce).

### **2.2 Formatting & Localization**

*   **[MUST]** The conversion from domain object `T` to printable string MUST use the `DataGridColumnConfig.valueExtractor`.
*   **[MUST]** If a column possesses a custom `formatter` (e.g., currency or date format), the adapter MUST apply this formatter before passing the string to the `ExportDataTable`.

## **3. CONCRETE OUTPUT GENERATORS**

### **3.1 PDF Generation (`pdf` / `printing` packages)**

*   **[MUST] Layout Independence:** The `PdfExporter` must be able to generate a standard grid/table layout from any `ExportDataTable` automatically.
*   **[MUST] Templates:** If domain-specific layouts are requested (e.g., a "Invoice Printout"), use the generic `getDetailJson` from the controller and feed it into a dedicated `InvoicePdfTemplate` class that implements `PdfTemplate`.
*   **[MUST] Pagination:** Table generators MUST automatically handle page breaks (`pw.Table.fromTextArray` or similar multi-page constructs).

### **3.2 CSV / Excel Export**

*   **[MUST]** Use standard robust CSV encoders (e.g., the `csv` package).
*   **[MUST]** Always enforce UTF-8 with BOM (Byte Order Mark) so Excel opens German umlauts correctly by default.

### **3.3 Analytics & Charts (`fl_chart` package)**

*   **[MUST] Data Aggregation:** Implement a `ChartDataTransformer` that accepts `DataGridController.filteredSortedItems` and groups/aggregates data based on configuration (e.g., "Sum of `nettopreis` grouped by `datum` (Month)").
*   **[MUST] Reactive Updates:** Charts must react to `DataGridController` filter changes automatically. If a user filters the grid via UI, the Chart MUST immediately reflect only the `filteredSortedItems`.

## **4. UI INTEGRATION (APP HEADER MENU)**

### **4.1 The Global "Exportieren" Menu**

*   **[MUST]** Export functionalities MUST NOT clutter the `VpitDataGrid` toolbar. Instead, they MUST be integrated into a new dedicated dropdown/menu point called **"Exportieren"** in the main application's header (AppBar / Top Menu).
*   **[MUST]** The menu MUST contain items like: "Drucken", "PDF erstellen", "CSV erstellen", "Analysen/Diagramme anzeigen".
*   **[MUST] Context-Sensitivity (List vs. Detail):**
    *   If no modal dialog is open, the export functions MUST pull `filteredSortedItems` from the currently active `DataGridController` to export the current view (the list).
    *   If a modal detail dialog (e.g., an invoice) is currently open, the export functions MUST detect this context and switch to exporting/printing the **detailed view** of that single record (using `controller.getDetailJson(item)` or the specific detail object) instead of the underlying list.
*   **[MUST]** Explicit export dialogs (for selecting extensive parameters) are purely *optional*. Direct execution (e.g., clicking "CSV erstellen" downloads the CSV of the visible data directly) is preferred.

### **5. REQUIRED AI CHECKLIST (Verify before generating code)**

* [ ] Custom Export commands use `DataGridController` to fetch data.
* [ ] Exports are triggered from the global "Exportieren" Header menu, NOT the grid toolbar.
* [ ] Export functions check if a Detail Dialog is active and switch to Detail-Export automatically.
* [ ] Data extraction relies on `DataGridColumnConfig.valueExtractor`.
* [ ] No domain-specific logic resides in the PDF or CSV exporter classes.
* [ ] `ExportDataTable` is used as the intermediary format.
* [ ] Date and Currency formatters are applied before export.
* [ ] CSV exports include UTF-8 BOM.
* [ ] Print layouts support automatic pagination for long tables.
