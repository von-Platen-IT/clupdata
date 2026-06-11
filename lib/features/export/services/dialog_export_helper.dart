import '../../../core/providers/export_context_provider.dart';
import '../../../widgets/data_grid_v2/data_grid_controller.dart';
import '../../../widgets/data_grid_v2/export/export_data_table.dart';
import '../domain/detail_export_provider.dart';

/// Shared helper for building export data from detail dialog items.
///
/// Provides two paths for building detail export contexts:
/// 1. **Provider mode** (preferred): Uses [DetailExportProvider] to get
///    ALL detail fields — no DataGrid dependency.
/// 2. **Legacy mode**: Uses DataGrid controller column configs.
class DialogExportHelper {
  DialogExportHelper._();

  /// Builds an [ExportContextData] from a [DetailExportProvider].
  ///
  /// This is the preferred method — it uses the provider's
  /// [DetailExportProvider.toExportDataTable] to get ALL detail fields,
  /// completely bypassing the DataGrid controller.
  static ExportContextData buildDetailExportContextFromProvider({
    required DetailExportProvider provider,
  }) {
    final dataTable = provider.toExportDataTable();

    return ExportContextData(
      mode: ExportMode.detail,
      dataTable: dataTable,
      entityType: provider.entityType,
      title: provider.title,
      subtitle: provider.subtitle,
    );
  }

  /// Builds an [ExportContextData] for a detail dialog export (legacy).
  ///
  /// [item] is the domain object to export (e.g., a Beitrag or Rechnung).
  /// [controller] provides the column configurations for value extraction.
  ///
  /// **Deprecated**: Use [buildDetailExportContextFromProvider] instead.
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
