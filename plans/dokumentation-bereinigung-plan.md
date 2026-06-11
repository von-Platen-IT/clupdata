# Dokumentation-Bereinigungsplan

**Erstellt:** 2026-05-06 | **Aktualisiert:** 2026-06-11 | Mode: Flutter Architect  
**Ziel:** Veraltete Projekt-Dokumentation bereinigen, gültige Dokumente strukturiert ablegen

---

## 1. Aktueller Projektzustand (Quellcode-Analyse)

| Eigenschaft | Wert |
|---|---|
| Schema-Version | **17** ([`database.dart:46`](lib/core/database/database.dart:46)) |
| `BeitraegeRepository` + `BemerkungRepository` | ✅ Implementiert |
| `tableName`-Overrides (4 Tabellen) | ✅ Implementiert |
| `_columnConfigsMap` in `DataGridController` | ✅ Implementiert |
| Bulk-Import/Export-Dialoge | ✅ Implementiert |
| Batch-Export-Feature | ✅ Implementiert |
| PDF-Template-System | ✅ Implementiert |
| `DialogExportButton` | ✅ Implementiert |
| `ListExportMenuButton` | ✅ Implementiert |
| `PdfTemplateSelector` | ✅ Implementiert |
| `DetailExportProvider`-Interface | ✅ Implementiert (5 Provider: Mitglied, Leistung, Ware, Beitrag, Rechnung) |
| `StatusManager`-Interface | ✅ Implementiert ([`status_manager.dart`](lib/core/models/status_manager.dart)) |
| `RechnungsnummerGenerator` | ✅ Implementiert ([`rechnungsnummer_generator.dart`](lib/core/data/rechnungsnummer_generator.dart)) |
| `EntityTypeInfo`-Enum | ✅ Implementiert ([`entity_type_info.dart`](lib/core/models/entity_type_info.dart)) |
| `CurrencyFormatter` | ✅ Implementiert ([`currency_formatter.dart`](lib/core/utils/currency_formatter.dart)) |
| Keyboard-Shortcuts | ✅ Implementiert ([`keyboard_shortcuts.dart`](lib/core/keyboard/keyboard_shortcuts.dart)) |
| `CreateActionRegistry` | ✅ Implementiert ([`create_action_provider.dart`](lib/core/providers/create_action_provider.dart)) |
| Beiträge Status-History-Grid | ✅ Implementiert ([`beitrag_status_history_grid.dart`](lib/features/beitraege/presentation/widgets/beitrag_status_history_grid.dart)) |
| SQL-JOIN MembersRepository | ✅ Implementiert (`watchMembersWithDetails()`) |
| Batch-Rechnungserstellung (Beiträge) | ✅ Implementiert ([`BeitraegeBatchService`](lib/features/rechnungserstellung/services/beitraege_batch_service.dart)) |
| Batch-Rechnungserstellung (Verkauf) | ❌ Noch nicht implementiert |

---

## 2. Aktuelle Struktur von `plans/`

### 🟢 AKTIVE PLÄNE / DOKUMENTATION (bleibt in `plans/`)

| # | Datei | Typ | Begründung |
|---|-------|-----|------------|
| 1 | `architektur-analyse.md` | Referenz | Umfassende Architektur-Analyse, Schema v17, aktualisiert am 2026-06-11 |
| 2 | `backup_dokumentation.md` | Feature-Doku | Dokumentiert aktives Backup/Restore-Feature |
| 3 | `DatabaseMigration.md` | Workflow-Guide | Zeitloser Leitfaden für Drift-Migrationen |
| 4 | `pdf_configuration.md` | Entwickler-Doku | PDF-Export-System – Template-Erstellung und Konfiguration |
| 5 | `pdf_print_refactoring.md` | Arbeitsplan | Teilweise erledigt (Schritt 2: BatchPdfExporter-Konsolidierung offen) |
| 6 | `rechnungbatch.md` | Arbeitsplan | Beiträge-Batch implementiert, Verkaufs-Batch noch offen |
| 7 | `dokumentation-bereinigung-plan.md` | Meta-Plan | Dieser Plan |

### 🔴 OBSOLET → `plans/obsolete/`

Diese Dateien wurden als vollständig implementiert verifiziert und nach `plans/obsolete/` verschoben:

| # | Datei | Begründung |
|---|-------|------------|
| 1 | `architecture_corrections_plan.md` | ✅ Alle 4 Issues implementiert (4.1 CreateActionRegistry, 4.2 Cross-Feature-Entkopplung, 4.3 BemerkungRepository-Integration, 4.4 ExportCache-Vereinfachung) |
| 2 | `beitraege_rechnungen_refactoring.md` | ✅ Alle 7 Schritte implementiert (RechnungsnummerGenerator, StatusManager, StatusBadge-Konsistenz, canSave-Validierung, Tests) |
| 3 | `beitraegeRefactoring.md` | ✅ Status-Historie als VpitDataGrid implementiert |
| 4 | `data_detail_export_plan.md` | ✅ DetailExportProvider-Interface + alle 5 Provider implementiert |
| 5 | `keyboard_shortcuts_plan.md` | ✅ Keyboard-Shortcuts mit MenuShortcuts-Klasse implementiert |
| 6 | `performance_corrections_plan.md` | ✅ Alle 7 Performance-Issues implementiert (columnConfigsMap, SQL-JOIN, DateFormat-Konstante, lazy allPlutoRows, addPostFrameCallback, Alters-Getter) |

---

## 3. Durchgeführte Bereinigungsoperationen

### Phase 1 (2026-05-06): Initiale Kategorisierung
- 19 veraltete Dokumente identifiziert (CSV-V1, Batch-Export, Schema-Fixes etc.)
- Kategorisierung in OBSOLET vs. GÜLTIG

### Phase 2 (2026-06-11): Aktualisierung nach Implementierungswelle
- 6 weitere Pläne als vollständig implementiert verifiziert → nach `plans/obsolete/` verschoben
- `architektur-analyse.md` aktualisiert (Schema v16→v17, UUID-Spalten, Rechnungserstellung-Feature, Migrations-Historie v17)
- `dokumentation-bereinigung-plan.md` (dieser Plan) auf aktuellen Stand gebracht

---

## 4. Aktuelle Verzeichnisstruktur

```
plans/
├── architektur-analyse.md             ← Architektur-Referenz (Schema v17)
├── backup_dokumentation.md            ← Feature-Dokumentation
├── DatabaseMigration.md               ← Workflow-Guide (zeitlos)
├── dokumentation-bereinigung-plan.md  ← Dieser Plan
├── pdf_configuration.md               ← Benutzer-/Entwicklerdokumentation
├── pdf_print_refactoring.md           ← Arbeitsplan (teilweise offen)
├── rechnungbatch.md                   ← Arbeitsplan (teilweise offen)
└── obsolete/                          ← 25 veraltete/abgeschlossene Pläne
    ├── architecture_corrections_plan.md
    ├── beitraege_rechnungen_refactoring.md
    ├── beitraegeRefactoring.md
    ├── data_detail_export_plan.md
    ├── keyboard_shortcuts_plan.md
    ├── performance_corrections_plan.md
    └── ... (19 weitere aus Phase 1)
```

**Bilanz:** 7 aktive Dokumente, 25 veraltete Dokumente nach `obsolete/` verschoben.
