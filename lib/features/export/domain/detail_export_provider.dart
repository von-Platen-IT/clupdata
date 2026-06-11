import '../../../widgets/data_grid_v2/export/export_data_table.dart';

/// Interface for providing detail export data from edit dialogs.
///
/// Each edit dialog creates a concrete implementation that knows
/// which fields to include in the export and how to format them.
/// This decouples the export from the DataGrid controller, allowing
/// detail dialogs to export ALL their fields (not just list columns).
///
/// Example:
/// ```dart
/// class RechnungDetailExportProvider implements DetailExportProvider {
///   final RechnungWithDetails data;
///   RechnungDetailExportProvider(this.data);
///
///   @override
///   String get entityType => 'rechnung';
///
///   @override
///   String get title => 'Rechnung ${data.rechnung.rechnungsnummer}';
///
///   @override
///   ExportDataTable toExportDataTable() {
///     // Build table with ALL detail fields...
///   }
/// }
/// ```
abstract class DetailExportProvider {
  /// Entity type identifier (e.g., 'mitglied', 'rechnung', 'beitrag').
  String get entityType;

  /// Display title for the export (e.g., 'Müller, Hans' or 'RE-2026-00001').
  String get title;

  /// Optional subtitle (e.g., customer name or invoice number).
  String? get subtitle;

  /// Builds an [ExportDataTable] with ALL detail fields.
  ///
  /// Returns a table with headers ['Feld', 'Wert'] containing
  /// every relevant field from the detail view, properly formatted.
  /// This includes fields that are NOT visible in the list DataGrid,
  /// such as Bemerkung, Status-Historie, Rechnungspositionen, etc.
  ExportDataTable toExportDataTable();
}
