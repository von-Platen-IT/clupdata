/// A generic, domain-agnostic data transfer object for exporting tabular data.
///
/// Acts as the single intermediary format between `DataGridController<T>`
/// (which holds typed domain objects) and concrete output generators
/// (CSV, PDF, Charts). All values are pre-formatted as display strings,
/// matching exactly what the user sees in the `VpitDataGrid`.
///
/// Example:
/// ```dart
/// final table = ExportDataTable(
///   title: 'Mitglieder',
///   headers: ['Name', 'Vorname', 'Alter'],
///   rows: [
///     ['Müller', 'Hans', '34'],
///     ['Schmidt', 'Anna', '28'],
///   ],
/// );
/// ```
class ExportDataTable {
  /// Optional title for the exported data set (e.g. feature screen name).
  final String title;

  /// Column header labels, extracted from [DataGridColumnConfig.title].
  final List<String> headers;

  /// Row data as pre-formatted strings. Each inner list matches the
  /// [headers] order exactly. Formatting (dates, currency) is already applied.
  final List<List<String>> rows;

  /// The timestamp when this export snapshot was created.
  final DateTime exportedAt;

  /// Creates an [ExportDataTable] with the given [headers] and [rows].
  const ExportDataTable({
    this.title = '',
    required this.headers,
    required this.rows,
    required this.exportedAt,
  });

  /// The total number of data rows (excludes the header).
  int get rowCount => rows.length;

  /// The number of columns.
  int get columnCount => headers.length;
}
