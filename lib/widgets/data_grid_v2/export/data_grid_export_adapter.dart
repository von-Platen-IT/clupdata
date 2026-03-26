import '../data_grid_column_config.dart';
import '../data_grid_controller.dart';
import 'export_data_table.dart';

/// Adapter that converts a [DataGridController]'s typed domain objects
/// into a generic [ExportDataTable] suitable for any output generator.
///
/// The adapter uses each column's [DataGridColumnConfig.valueExtractor]
/// to pull raw values, then applies the optional [formatter] to produce
/// display-ready strings — guaranteeing that exports match the UI exactly.
///
/// This adapter works with any [DataGridController] regardless of its
/// generic type parameter, making it suitable for use with the
/// [activeDataGridControllerProvider] which returns [DataGridController<dynamic>].
///
/// Usage:
/// ```dart
/// final controller = ref.read(activeDataGridControllerProvider);
/// final adapter = DataGridExportAdapter();
/// final table = adapter.extractVisible(controller, title: 'Mitglieder');
/// ```
class DataGridExportAdapter {
  /// Extracts the currently **filtered and sorted** items (what the user sees).
  ExportDataTable extractVisible(
    DataGridController<dynamic> controller, {
    String title = '',
  }) {
    return _extract(
      controller.filteredSortedItems,
      controller.columnConfigs,
      title: title,
    );
  }

  /// Extracts **all** raw items regardless of active filters or search.
  ExportDataTable extractAll(
    DataGridController<dynamic> controller, {
    String title = '',
  }) {
    return _extract(controller.items, controller.columnConfigs, title: title);
  }

  /// Core extraction logic shared by [extractVisible] and [extractAll].
  ///
  /// Uses dynamic invocation to work with any controller type without
  /// requiring explicit type parameters.
  ExportDataTable _extract(
    List<dynamic> items,
    List<DataGridColumnConfig<dynamic>> configs, {
    String title = '',
  }) {
    final headers = configs.map((c) => c.title).toList();

    final rows = items.map((item) {
      return configs.map((config) {
        // Dynamic invocation to avoid type parameter issues
        final rawValue = config.valueExtractor(item);

        // Apply the column's custom formatter if present
        if (config.formatter != null) {
          return config.formatter!(rawValue);
        }

        // Default toString conversion, treating null as empty string
        return rawValue?.toString() ?? '';
      }).toList();
    }).toList();

    return ExportDataTable(
      title: title,
      headers: headers,
      rows: rows,
      exportedAt: DateTime.now(),
    );
  }
}
