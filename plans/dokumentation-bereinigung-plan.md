# Dokumentation-Bereinigungsplan

**Erstellt:** 2026-05-06 | Mode: Flutter Architect  
**Ziel:** Veraltete Projekt-Dokumentation bereinigen, gültige Dokumente strukturiert ablegen

---

## 1. Aktueller Projektzustand (Quellcode-Analyse)

| Eigenschaft | Wert |
|---|---|
| Schema-Version | **17** ([`database.dart:47`](lib/core/database/database.dart:47)) |
| `BeitraegeRepository` + `BemerkungRepository` | ✅ Implementiert ([`beitraege_repository.dart:14`](lib/features/beitraege/data/beitraege_repository.dart:14)) |
| `tableName`-Overrides (4 Tabellen) | ✅ Implementiert ([`mitglied_table.dart:19`](lib/core/database/tables/mitglied_table.dart:19), [`beitraege_table.dart:15`](lib/core/database/tables/beitraege_table.dart:15), [`rechnung_table.dart:14`](lib/core/database/tables/rechnung_table.dart:14), [`rechnung_position_table.dart:13`](lib/core/database/tables/rechnung_position_table.dart:13)) |
| `_columnConfigsMap` in `DataGridController` | ✅ Implementiert ([`data_grid_controller.dart:29`](lib/widgets/data_grid_v2/data_grid_controller.dart:29)) |
| Bulk-Import/Export-Dialoge | ✅ Implementiert ([`csv_bulk_import_dialog.dart`](lib/common_widgets/csv_bulk_import_dialog.dart), [`csv_bulk_export_dialog.dart`](lib/common_widgets/csv_bulk_export_dialog.dart)) |
| Batch-Export-Feature | ✅ Implementiert ([`batch_export_service.dart`](lib/features/export/services/batch_export_service.dart), [`batch_pdf_exporter.dart`](lib/features/export/services/batch_pdf_exporter.dart)) |
| PDF-Template-System | ✅ Implementiert ([`pdf_template.dart`](lib/widgets/data_grid_v2/export/pdf/pdf_template.dart), [`pdf_template_registry.dart`](lib/widgets/data_grid_v2/export/pdf/pdf_template_registry.dart)) |
| `DialogExportButton` | ✅ Implementiert ([`dialog_export_button.dart`](lib/features/export/presentation/dialog_export_button.dart)) |
| `ListExportMenuButton` | ✅ Implementiert ([`list_export_menu_button.dart`](lib/features/export/presentation/list_export_menu_button.dart)) |
| `PdfTemplateSelector` | ✅ Implementiert ([`pdf_template_selector.dart`](lib/widgets/data_grid_v2/export/pdf/pdf_template_selector.dart)) |
| CSV V1-Service | ❌ Gelöscht (`csv_import_service.dart` existiert nicht mehr) |
| CSV V1-Dialog | ❌ Gelöscht (`csv_import_dialog.dart` existiert nicht mehr) |

---

## 2. Datei-Kategorisierung

### 🔴 OBSOLET → `plans/obsolete/`

Diese Dateien beschreiben abgeschlossene Aufgaben, verweisen auf gelöschte Dateien oder sind inhaltlich überholt:

| # | Datei | Begründung |
|---|-------|------------|
| 1 | `plans/AGENTS.md` | Duplikat der Root-AGENTS.md, Schema-Version 15 (aktuell: 17) |
| 2 | `plans/AskKimi.md` | Projektübersicht für externes KI-Tool, Schema-Version 15, inhaltlich durch README + structur.md abgedeckt |
| 3 | `plans/batch_export_feature_plan.md` | ✅ Implementiert – Batch-Export existiert vollständig |
| 4 | `plans/batch_export_refactoring_plan.md` | ✅ Implementiert – Export-Entkopplung durchgeführt |
| 5 | `plans/ClupData_PDF_Export_Architektur.pdf` | Wahrscheinlich veraltet, PDF lässt sich nicht leicht prüfen, aber Architektur hat sich stark verändert |
| 6 | `plans/csv_import_export_fixes.md` | ✅ Implementiert, verweist auf gelöschten V1-Service |
| 7 | `plans/csv_import_export_implementation_summary.md` | ✅ Implementiert, verweist auf gelöschten V1-Service |
| 8 | `plans/csv_import_export_robustness_plan.md` | ✅ Implementiert, verweist auf gelöschten V1-Service |
| 9 | `plans/csv_import_plan.md` | ✅ Superseded – V1-Dialog und V1-Service existieren nicht mehr |
| 10 | `plans/csv-bulk-import-export-redesign.md` | ✅ Implementiert – Bulk-Dialoge existieren |
| 11 | `plans/csv-bulk-import-export-refactoring.md` | ✅ Implementiert – Refactoring durchgeführt |
| 12 | `plans/database_code_generation_fix.md` | Einmaliger Fix, Schema-Version 15, abgeschlossen |
| 13 | `plans/DataMaintenanceUi.md` | Verweist auf `lib/widgets/data_grid/app_data_grid.dart` (existiert nicht mehr, jetzt `vpit_data_grid.dart`) |
| 14 | `plans/dialog_export_integration.md` | ✅ Implementiert – `DialogExportButton` existiert |
| 15 | `plans/fix_completion_summary.md` | Einmaliger Fix (Code-Generation), abgeschlossen |
| 16 | `plans/pdf_export_menu_redesign.md` | ✅ Implementiert – `ListExportMenuButton` existiert |
| 17 | `plans/pdf_template_selection_architecture.md` | ✅ Implementiert – `PdfTemplateSelector` existiert |
| 18 | `plans/redundanz-analyse.md` | Leere Datei (0 Bytes Inhalt) |
| 19 | `plans/features/drift-table-naming-convention.md` | ✅ Implementiert – `tableName`-Overrides in allen 4 Tabellen vorhanden |

### 🟢 GÜLTIG → Bleibt in `plans/` (aus `unchecked/` heraus)

Diese Dateien sind noch relevant als Arbeitsdokumente oder Referenz:

| # | Datei | Zielordner | Begründung |
|---|-------|------------|------------|
| 1 | `plans/architecture_corrections_plan.md` | `plans/` | Teilweise umgesetzt (4.3 ✅), 4.1/4.2/4.4 offen – Arbeitsdokument |
| 2 | `plans/architektur-analyse.md` | `plans/` | Aktuelle Architektur-Analyse, Schema-Version 16 (fast aktuell), umfassende Referenz |
| 3 | `plans/backup_dokumentation.md` | `plans/` | Dokumentiert aktives Feature, referenzierte Dateien existieren alle |
| 4 | `plans/DatabaseMigration.md` | `plans/` | Workflow-Guide für Migrationen – dauerhaft relevant |
| 5 | `plans/pdf_configuration.md` | `plans/` | Benutzer-/Entwicklerdokumentation für PDF-Export – dauerhaft relevant |
| 6 | `plans/performance_corrections_plan.md` | `plans/` | Teilweise umgesetzt (3.5 ✅), andere Punkte offen – Arbeitsdokument |

---

## 3. Verschiebe-Operationen

### Schritt 1: Alle Plandateien → `plans/unchecked/`

Alle MD-Dateien aus `plans/` (inkl. Unterordner) nach `plans/unchecked/` verschieben.

### Schritt 2: Gültige Dateien zurück verschieben

```
plans/unchecked/architecture_corrections_plan.md → plans/architecture_corrections_plan.md
plans/unchecked/architektur-analyse.md           → plans/architektur-analyse.md
plans/unchecked/backup_dokumentation.md           → plans/backup_dokumentation.md
plans/unchecked/DatabaseMigration.md              → plans/DatabaseMigration.md
plans/unchecked/pdf_configuration.md              → plans/pdf_configuration.md
plans/unchecked/performance_corrections_plan.md   → plans/performance_corrections_plan.md
```

### Schritt 3: Obsolete Dateien verschieben

```
plans/unchecked/AGENTS.md                              → plans/obsolete/AGENTS.md
plans/unchecked/AskKimi.md                             → plans/obsolete/AskKimi.md
plans/unchecked/batch_export_feature_plan.md           → plans/obsolete/batch_export_feature_plan.md
plans/unchecked/batch_export_refactoring_plan.md       → plans/obsolete/batch_export_refactoring_plan.md
plans/unchecked/ClupData_PDF_Export_Architektur.pdf     → plans/obsolete/ClupData_PDF_Export_Architektur.pdf
plans/unchecked/csv_import_export_fixes.md             → plans/obsolete/csv_import_export_fixes.md
plans/unchecked/csv_import_export_implementation_summary.md → plans/obsolete/csv_import_export_implementation_summary.md
plans/unchecked/csv_import_export_robustness_plan.md   → plans/obsolete/csv_import_export_robustness_plan.md
plans/unchecked/csv_import_plan.md                     → plans/obsolete/csv_import_plan.md
plans/unchecked/csv-bulk-import-export-redesign.md     → plans/obsolete/csv-bulk-import-export-redesign.md
plans/unchecked/csv-bulk-import-export-refactoring.md  → plans/obsolete/csv-bulk-import-export-refactoring.md
plans/unchecked/database_code_generation_fix.md        → plans/obsolete/database_code_generation_fix.md
plans/unchecked/DataMaintenanceUi.md                   → plans/obsolete/DataMaintenanceUi.md
plans/unchecked/dialog_export_integration.md           → plans/obsolete/dialog_export_integration.md
plans/unchecked/fix_completion_summary.md              → plans/obsolete/fix_completion_summary.md
plans/unchecked/pdf_export_menu_redesign.md            → plans/obsolete/pdf_export_menu_redesign.md
plans/unchecked/pdf_template_selection_architecture.md → plans/obsolete/pdf_template_selection_architecture.md
plans/unchecked/redundanz-analyse.md                   → plans/obsolete/redundanz-analyse.md
plans/unchecked/drift-table-naming-convention.md       → plans/obsolete/drift-table-naming-convention.md
```

### Schritt 4: Leeren Ordner `plans/unchecked/` und `plans/features/` aufräumen

Nach dem Verschieben sollten `plans/unchecked/` und `plans/features/` leer sein und können gelöscht werden.

---

## 4. Ergebnis

```
plans/
├── architecture_corrections_plan.md   ← Arbeitsdokument (teilweise offen)
├── architektur-analyse.md             ← Aktuelle Architektur-Referenz
├── backup_dokumentation.md            ← Feature-Dokumentation
├── DatabaseMigration.md               ← Workflow-Guide
├── dokumentation-bereinigung-plan.md  ← Dieser Plan
├── pdf_configuration.md               ← Benutzerdokumentation
├── performance_corrections_plan.md    ← Arbeitsdokument (teilweise offen)
├── adr/                               ← (leer, für zukünftige ADRs)
├── obsolete/                          ← 19 veraltete Dateien
│   ├── AGENTS.md
│   ├── AskKimi.md
│   ├── batch_export_feature_plan.md
│   ├── batch_export_refactoring_plan.md
│   ├── ClupData_PDF_Export_Architektur.pdf
│   ├── csv_import_export_fixes.md
│   ├── csv_import_export_implementation_summary.md
│   ├── csv_import_export_robustness_plan.md
│   ├── csv_import_plan.md
│   ├── csv-bulk-import-export-redesign.md
│   ├── csv-bulk-import-export-refactoring.md
│   ├── database_code_generation_fix.md
│   ├── DataMaintenanceUi.md
│   ├── dialog_export_integration.md
│   ├── drift-table-naming-convention.md
│   ├── fix_completion_summary.md
│   ├── pdf_export_menu_redesign.md
│   ├── pdf_template_selection_architecture.md
│   └── redundanz-analyse.md
└── schema/                            ← (leer, für zukünftige Schema-Dokus)
```

**Bilanz:** 6 gültige Dokumente behalten, 19 veraltete Dokumente nach `obsolete/` verschoben.
