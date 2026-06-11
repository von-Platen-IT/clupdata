# Plan: PDF-Listenexport vereinfachen — Immer alle Spalten

> **Status**: Planung | **Erstellt**: 2026-06-11 | **Modus**: Flutter Architect

## Problem

Beim PDF-Export und Drucken aus der Listenansicht zeigt `ExportOptionsDialog` eine unnötige Auswahl:
- "Sichtbare Spalten" vs. "Alle Details"

Diese Unterscheidung verwirrt. Es sollen **immer alle Spalten** exportiert werden.

## Lösung

### Schritt 1: `ListExportMenuButton` — ExportOptionsDialog entfernen

**Datei**: [`lib/features/export/presentation/list_export_menu_button.dart`](lib/features/export/presentation/list_export_menu_button.dart)

**PDF-Export (Zeile 139-150)**: `ExportOptionsDialog` überspringen, direkt `PdfPreviewDialog` öffnen mit `useFullTable: true`.

```dart
// ALT:
final exportData = await showDialog<PdfExportData>(
  context: context,
  builder: (_) => ExportOptionsDialog(contextData: exportContext),
);
if (exportData != null && context.mounted) {
  await showDialog(
    context: context,
    builder: (_) => PdfPreviewDialog(exportData: exportData),
  );
}

// NEU:
final exporter = PdfExporter();
final exportData = exporter.prepareExport(exportContext, useFullTable: true);
if (context.mounted) {
  await showDialog(
    context: context,
    builder: (_) => PdfPreviewDialog(exportData: exportData),
  );
}
```

**Drucken (Zeile 160-184)**: `useFullTable: false` → `useFullTable: true`.

### Schritt 2: Import bereinigen

`ExportOptionsDialog`-Import entfernen (falls nicht mehr verwendet).

### Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `lib/features/export/presentation/list_export_menu_button.dart` | ExportOptionsDialog entfernen, immer `useFullTable: true` |

### Keine Änderungen nötig

- `ExportOptionsDialog` wird **nicht gelöscht** — könnte noch von anderen Stellen referenziert werden
- `DialogExportButton` und `DialogExportMenuButton` verwenden bereits `useFullTable: true`
