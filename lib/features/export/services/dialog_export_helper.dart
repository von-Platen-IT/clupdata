import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/data_grid_controller.dart';
import '../../../widgets/data_grid_v2/export/export_data_table.dart';

/// Shared helper for building export data from detail dialog items.
///
/// Extracts the duplicated `rows`-building logic from
/// [DialogExportButton] and [DialogExportMenuButton].
class DialogExportHelper {
  DialogExportHelper._();

  /// Builds an [ExportContextData] for a detail dialog export.
  ///
  /// [item] is the domain object to export (e.g., a Beitrag or Rechnung).
  /// [controller] provides the column configurations for value extraction.
  static ExportContextData buildDetailExportContext({
    required dynamic item,
    required String entityType,
    required String title,
    String? subtitle,
    required DataGridController controller,
  }) {
    final rows = controller.columnConfigs.map((config) {
      final rawValue = (config as dynamic).valueExtractor(item);
      final formattedValue = config.formatter != null
          ? config.formatter!(rawValue)
          : rawValue?.toString() ?? '';
      return [config.title, formattedValue];
    }).toList();

    final dataTable = ExportDataTable(
      title: title,
      headers: ['Feld', 'Wert'],
      rows: rows,
      exportedAt: DateTime.now(),
    );

    return ExportContextData(
      mode: ExportMode.detail,
      dataTable: dataTable,
      entityType: entityType,
      title: title,
      subtitle: subtitle,
    );
  }
}