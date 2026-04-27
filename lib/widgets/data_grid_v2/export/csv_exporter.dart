import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'export_data_table.dart';

/// Generates CSV files from an [ExportDataTable].
///
/// The output uses semicolons as delimiters (standard for German locale /
/// Excel DE) and prepends a UTF-8 BOM so that programs like Excel and
/// LibreOffice Calc correctly interpret German umlauts and special characters.
///
/// Usage:
/// ```dart
/// final exporter = CsvExporter();
/// final file = await exporter.export(table, title: 'Mitglieder');
/// ```
class CsvExporter {
  /// Exports the given [data] as a semicolon-separated CSV file.
  ///
  /// If [filePath] is provided, the CSV is written directly to that path.
  /// Otherwise, the file is named `{title}_{yyyy-MM-dd_HHmmss}.csv` and
  /// stored in the `exports/` directory relative to the running executable.
  ///
  /// Returns the created [File] for further processing (e.g. showing a
  /// success notification with the path).
  Future<File> export(
    ExportDataTable data, {
    String? title,
    String? filePath,
  }) async {
    final effectiveTitle = title ?? data.title;
    final sanitizedTitle = _sanitizeFileName(
      effectiveTitle.isNotEmpty ? effectiveTitle : 'export',
    );

    // Build the CSV content using csv v8 CsvEncoder API
    final allRows = <List<dynamic>>[data.headers, ...data.rows];

    // CsvEncoder with semicolon delimiter for German Excel and UTF-8 BOM
    const encoder = CsvEncoder(fieldDelimiter: ';', addBom: true);
    final csvString = encoder.convert(allRows);

    if (filePath != null) {
      // Write directly to the user-selected path
      final file = File(filePath);
      await file.writeAsString(csvString);
      return file;
    }

    // Fallback: Determine the output directory next to the executable
    final exportDir = await _ensureExportDirectory();

    // Generate timestamped filename
    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(data.exportedAt);
    final fileName = '${sanitizedTitle}_$timestamp.csv';
    final file = File('${exportDir.path}/$fileName');

    await file.writeAsString(csvString);
    return file;
  }

  /// Ensures the `exports/` directory exists next to the application
  /// executable and returns it.
  Future<Directory> _ensureExportDirectory() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent;
    final exportDir = Directory('${executableDir.path}/exports');

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir;
  }

  /// Removes characters from [name] that are invalid in file names.
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
}
