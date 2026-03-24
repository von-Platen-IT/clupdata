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
/// Usage:
/// ```dart
/// final adapter = DataGridExportAdapter<MemberRowData>();
/// final table = adapter.extractVisible(controller, title: 'Mitglieder');
/// ```
class DataGridExportAdapter<T> {
  /// Extracts the currently **filtered and sorted** items (what the user sees).
  ExportDataTable extractVisible(
    DataGridController<T> controller, {
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
    DataGridController<T> controller, {
    String title = '',
  }) {
    return _extract(
      controller.items,
      controller.columnConfigs,
      title: title,
    );
  }

  /// Core extraction logic shared by [extractVisible] and [extractAll].
  ///
  /// Iterates over each [item] and each [config], applies the
  /// [valueExtractor] and optional [formatter], and collects
  /// everything into an [ExportDataTable].
  ExportDataTable _extract(
    List<T> items,
    List<DataGridColumnConfig<T>> configs, {
    String title = '',
  }) {
    final headers = configs.map((c) => c.title).toList();

    final rows = items.map((item) {
      return configs.map((config) {
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
