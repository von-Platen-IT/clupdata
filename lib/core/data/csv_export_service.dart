import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';

/// Zentraler Service für CSV-Export.
///
/// Bietet:
/// - UTF-8 BOM Support
/// - Konfigurierbare Trennzeichen
/// - European Number Format (1.234,56)
/// - ISO-8601 Datumsformat für DateTime-Spalten
class CsvExportService {
  CsvExportService._();

  /// Standard-Trennzeichen (Semicolon für Deutsch/Excel)
  static const String defaultDelimiter = ';';

  /// Exportiert eine Tabelle als CSV mit Logging und Validierung.
  ///
  /// [tableName]: Name der SQL-Tabelle
  /// [useEuropeanFormat]: Zahlen als 1.234,56 formatieren
  /// [dateFormat]: Datumsformat für DateTime-Spalten (Default: dd.MM.yyyy)
  static Future<String> exportTable(
    AppDatabase db,
    String tableName, {
    String delimiter = defaultDelimiter,
    bool useEuropeanFormat = true,
    String dateFormat = 'dd.MM.yyyy',
  }) async {
    debugPrint('=== CSV Export Service: $tableName ===');

    // Schema für Datentyp-Erkennung laden
    final schema = await _getTableSchema(db, tableName);
    debugPrint('Spalten-Schema geladen: ${schema.length} Spalten');

    if (schema.isEmpty) {
      debugPrint('FEHLER: Keine Spalten gefunden');
      throw Exception('Tabelle "$tableName" hat keine Spalten');
    }

    // Alle Daten laden (SELECT * = alle Spalten)
    final rows = await db.customSelect('SELECT * FROM $tableName').get();
    debugPrint('Datenzeilen geladen: ${rows.length}');

    // Header (ALLE Spalten aus Schema)
    final headers = schema.map((c) => c.name).toList();
    debugPrint('Header: ${headers.join(', ')}');

    // Daten konvertieren - ALLE Spalten müssen berücksichtigt werden
    final dataRows = <List<String>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final csvRow = <String>[];

      for (final col in schema) {
        try {
          final value = row.read<dynamic>(col.name);
          final formatted = _formatValue(
            value,
            col.dataType,
            useEuropeanFormat,
            dateFormat,
          );
          csvRow.add(formatted);
        } catch (e) {
          debugPrint(
            'WARNUNG Zeile $i, Spalte "${col.name}": Fehler beim Formatieren: $e',
          );
          csvRow.add(''); // Fallback: Leerer String
        }
      }

      // Validierung: Jede Zeile muss gleich viele Werte wie Header haben
      if (csvRow.length != headers.length) {
        debugPrint(
          'FEHLER Zeile $i: ${csvRow.length} Werte, aber ${headers.length} Header erwartet',
        );
        throw Exception(
          'CSV-Struktur inkonsistent: Zeile $i hat ${csvRow.length} Werte, erwartet ${headers.length}',
        );
      }

      dataRows.add(csvRow);
    }

    debugPrint('Daten formatiert: ${dataRows.length} Zeilen');

    // CSV erzeugen
    final allRows = <List<dynamic>>[headers, ...dataRows];
    final encoder = CsvEncoder(fieldDelimiter: delimiter, addBom: true);
    final csv = encoder.convert(allRows);

    debugPrint('CSV generiert: ${csv.length} Zeichen');
    debugPrint('=== CSV Export erfolgreich ===');

    return csv;
  }

  /// Exportiert eine Tabelle in eine Datei.
  static Future<File> exportTableToFile(
    AppDatabase db,
    String tableName,
    String filePath, {
    String delimiter = defaultDelimiter,
    bool useEuropeanFormat = true,
    String dateFormat = 'dd.MM.yyyy',
  }) async {
    final csv = await exportTable(
      db,
      tableName,
      delimiter: delimiter,
      useEuropeanFormat: useEuropeanFormat,
      dateFormat: dateFormat,
    );

    final file = File(filePath);
    await file.writeAsString(csv);
    return file;
  }

  /// Formatiert einen Wert für CSV-Export.
  ///
  /// NULL-Werte werden als '<NULL>' exportiert, damit sie beim Re-Import
  /// von leeren Strings unterscheidbar sind.
  static String _formatValue(
    dynamic value,
    ColumnDataType type,
    bool useEuropeanFormat,
    String dateFormat,
  ) {
    // NULL explizit markieren für Re-Import-Kompatibilität
    if (value == null) {
      return '<NULL>';
    }

    switch (type) {
      case ColumnDataType.datetime:
        if (value is DateTime) {
          return DateFormat(dateFormat).format(value);
        }
        return value.toString();

      case ColumnDataType.real:
        if (value is double) {
          if (useEuropeanFormat) {
            // 1234.56 -> 1.234,56
            return _formatEuropeanNumber(value);
          }
          return value.toString();
        }
        return value.toString();

      case ColumnDataType.boolean:
        if (value is bool) return value ? '1' : '0';
        if (value is int) return value == 1 ? '1' : '0';
        return value.toString();

      case ColumnDataType.integer:
      case ColumnDataType.text:
        return value.toString();
    }
  }

  /// Formatiert eine Zahl im europäischen Format.
  static String _formatEuropeanNumber(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    // Tausender-Trennzeichen
    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count == 3) {
        buffer.write('.');
        count = 0;
      }
      buffer.write(intPart[i]);
      count++;
    }

    final formatted = buffer.toString().split('').reversed.join();
    return '$formatted,$decPart';
  }

  /// Lädt das Schema einer Tabelle.
  static Future<List<_ColumnInfo>> _getTableSchema(
    AppDatabase db,
    String tableName,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info($tableName)').get();

    // DateTime-Spalten aus der Mapping-Liste
    final dateTimeCols = _getDateTimeColumns(tableName);

    return rows.map((row) {
      final name = row.read<String>('name');
      final sqlType = row.read<String>('type');

      ColumnDataType dataType;
      if (dateTimeCols.contains(name)) {
        dataType = ColumnDataType.datetime;
      } else if (sqlType.toUpperCase() == 'REAL') {
        dataType = ColumnDataType.real;
      } else if (sqlType.toUpperCase() == 'INTEGER') {
        dataType = ColumnDataType.integer;
      } else {
        dataType = ColumnDataType.text;
      }

      return _ColumnInfo(name: name, dataType: dataType);
    }).toList();
  }

  /// Gibt die DateTime-Spalten für eine Tabelle zurück.
  static List<String> _getDateTimeColumns(String tableName) {
    final mapping = <String, List<String>>{
      'mitglied': [
        'geboren',
        'vertrag_kontierung',
        'vertrag_laufzeit_von',
        'vertrag_laufzeit_bis',
      ],
      'beitrag': [
        'rechnungsdatum',
        'faelligkeitsdatum',
        'bezahlt_am',
        'erstellt_am',
      ],
      'rechnung': [
        'rechnungsdatum',
        'faelligkeitsdatum',
        'bezahlt_am',
        'erstellt_am',
      ],
    };
    return mapping[tableName] ?? [];
  }
}

/// Interne Column-Info.
class _ColumnInfo {
  final String name;
  final ColumnDataType dataType;

  const _ColumnInfo({required this.name, required this.dataType});
}

/// Datentypen für Export.
enum ColumnDataType { integer, real, text, boolean, datetime }
