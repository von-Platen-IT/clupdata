import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';

/// Zentraler Service für CSV-Export mit UUID-Unterstützung.
///
/// Exportiert Datenbank-Tabellen als CSV. Statt der lokalen `id` wird die
/// `uuid`-Spalte exportiert. Fremdschlüssel (`*_id`) werden als `*_uuid`
/// exportiert, damit CSV-Dateien instanzunabhängig sind.
///
/// Features:
/// - UTF-8 BOM für Excel-Kompatibilität
/// - UUID-basierter Export (keine lokalen IDs)
/// - Konfigurierbare Trennzeichen
/// - European Number Format (1.234,56)
/// - Flexible Datumsformate
class CsvExportService {
  CsvExportService._();

  /// Standard-Trennzeichen (Semicolon für Deutsch/Excel)
  static const String defaultDelimiter = ';';

  /// Mapping: Tabellenname → Liste der FK-Spaltennamen (die als UUID exportiert werden)
  static const Map<String, List<String>> _fkColumnsByTable = {
    'bemerkung': [],
    'stammdaten': [],
    'preis': ['bemerkung_id'],
    'leistung': ['preis_id', 'bemerkung_id'],
    'mitglied': ['leistung_id', 'preis_id', 'bemerkung_id'],
    'waren': ['bemerkung_id'],
    'beitrag': ['mitglied_id', 'leistung_id', 'preis_id', 'bemerkung_id'],
    'beitrag_status_verlauf': ['beitrag_id'],
    'rechnung': ['mitglied_id', 'bemerkung_id'],
    'rechnung_position': ['rechnung_id', 'waren_id'],
  };

  /// Mapping: Tabellenname → Liste der DateTime-Spaltennamen
  static const Map<String, List<String>> _dateTimeColumnsByTable = {
    'bemerkung': ['datum_erstellt'],
    'mitglied': [
      'geboren',
      'vertrag_kontierung',
      'vertrag_laufzeit_von',
      'vertrag_laufzeit_bis',
    ],
    'beitrag': ['kontiert_am', 'status_datum', 'abrechnungs_zeitraum'],
    'beitrag_status_verlauf': ['geaendert_am'],
    'rechnung': [
      'datum',
      'faellig_am',
      'bezahlt_am',
      'erstellt_am',
      'aktualisiert_am',
    ],
    'waren': ['erstellt_am', 'aktualisiert_am'],
  };

  /// Exportiert eine Tabelle als CSV.
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

    // Alle Daten laden
    final rows = await db.customSelect('SELECT * FROM $tableName').get();
    debugPrint('Datenzeilen geladen: ${rows.length}');

    // Header generieren: id wird durch uuid ersetzt, FK-Spalten werden als *_uuid exportiert
    final headers = _buildExportHeaders(tableName, schema);
    debugPrint('Export-Header: ${headers.join(', ')}');

    // Daten konvertieren
    final dataRows = <List<String>>[];
    final fkColumns = _fkColumnsByTable[tableName] ?? [];
    final fkUuidCache =
        <String, Map<String, String>>{}; // Tabellenname → {id → uuid}

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final csvRow = <String>[];

      for (final col in schema) {
        try {
          final rawValue = row.data[col.name];

          // id-Spalte: überspringen (wird durch uuid ersetzt)
          if (col.name == 'id') continue;

          // uuid-Spalte: direkt übernehmen
          if (col.name == 'uuid') {
            csvRow.add(rawValue?.toString() ?? '');
            continue;
          }

          // FK-Spalte: ID in UUID auflösen
          if (fkColumns.contains(col.name)) {
            final fkValue = rawValue;
            if (fkValue == null) {
              csvRow.add('<NULL>');
            } else {
              final fkTableName = _fkTableName(col.name);
              final uuid = await _resolveFkToUuid(
                db,
                fkTableName,
                fkValue as int,
                fkUuidCache,
              );
              csvRow.add(uuid ?? '<NULL>');
            }
            continue;
          }

          // Normale Spalten formatieren
          final formatted = _formatValue(
            rawValue,
            col.dataType,
            useEuropeanFormat,
            dateFormat,
          );
          csvRow.add(formatted);
        } catch (e) {
          debugPrint('WARNUNG Zeile $i, Spalte "${col.name}": Fehler: $e');
          csvRow.add('');
        }
      }

      // Validierung
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

  /// Baut die Export-Header: id wird durch uuid ersetzt, FK-Spalten als *_uuid.
  static List<String> _buildExportHeaders(
    String tableName,
    List<_ColumnInfo> schema,
  ) {
    final fkColumns = _fkColumnsByTable[tableName] ?? [];
    final headers = <String>[];

    for (final col in schema) {
      if (col.name == 'id') continue; // id überspringen

      if (fkColumns.contains(col.name)) {
        // FK-Spalte: mitglied_id → mitglied_uuid
        final fkName = col.name.replaceFirst(RegExp(r'_id$'), '_uuid');
        headers.add(fkName);
      } else {
        headers.add(col.name);
      }
    }

    return headers;
  }

  /// Ermittelt den Tabellennamen aus einem FK-Spaltennamen.
  /// z.B. "mitglied_id" → "mitglied", "bemerkung_id" → "bemerkung"
  static String _fkTableName(String fkColumnName) {
    return fkColumnName.replaceFirst(RegExp(r'_id$'), '');
  }

  /// Löst eine lokale ID in eine UUID auf, mit Caching.
  static Future<String?> _resolveFkToUuid(
    AppDatabase db,
    String tableName,
    int id,
    Map<String, Map<String, String>> cache,
  ) async {
    // Cache füllen falls nötig
    if (!cache.containsKey(tableName)) {
      final rows = await db
          .customSelect('SELECT id, uuid FROM $tableName')
          .get();
      cache[tableName] = {
        for (final row in rows)
          row.read<int>('id').toString(): row.read<String>('uuid'),
      };
    }

    return cache[tableName]![id.toString()];
  }

  /// Formatiert einen Wert für CSV-Export.
  static String _formatValue(
    dynamic value,
    ColumnDataType type,
    bool useEuropeanFormat,
    String dateFormat,
  ) {
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

  /// Formatiert eine Zahl im europäischen Format (1.234,56).
  static String _formatEuropeanNumber(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

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

  /// Lädt das Schema einer Tabelle via PRAGMA table_info.
  static Future<List<_ColumnInfo>> _getTableSchema(
    AppDatabase db,
    String tableName,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
    final dateTimeCols = _dateTimeColumnsByTable[tableName] ?? [];

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

  // -------------------------------------------------------------------------
  // Bulk Export
  // -------------------------------------------------------------------------

  /// Exportiert mehrere Tabellen als CSV-Dateien in einen Ordner.
  ///
  /// [tableNames]: Liste der zu exportierenden Tabellen
  /// [outputDir]: Zielordner (muss existieren)
  /// [delimiter]: CSV-Trennzeichen
  ///
  /// Erzeugt Dateien im Format: {tabellenname}.csv
  static Future<BulkExportResult> exportMultipleTables(
    AppDatabase db,
    List<String> tableNames,
    String outputDir, {
    String delimiter = defaultDelimiter,
    bool useEuropeanFormat = true,
    String dateFormat = 'dd.MM.yyyy',
    void Function({
      required String currentTable,
      required int tableIndex,
      required int totalTables,
      required double tableProgress,
      required int tableExportedRows,
      required int tableTotalRows,
    })?
    onProgress,
  }) async {
    final tableResults = <BulkExportTableResult>[];
    var totalExported = 0;

    for (var i = 0; i < tableNames.length; i++) {
      final tableName = tableNames[i];
      final fileName = '$tableName.csv';
      final filePath = '${outputDir}${Platform.pathSeparator}$fileName';

      try {
        final csv = await exportTable(
          db,
          tableName,
          delimiter: delimiter,
          useEuropeanFormat: useEuropeanFormat,
          dateFormat: dateFormat,
        );

        final file = File(filePath);
        await file.writeAsString(csv);

        // Zeilen zählen (Header abziehen)
        final lineCount = csv.split('\n').length - 1;

        tableResults.add(
          BulkExportTableResult(
            tableName: tableName,
            fileName: fileName,
            success: true,
            exportedRows: lineCount,
          ),
        );

        totalExported += lineCount;

        onProgress?.call(
          currentTable: tableName,
          tableIndex: i,
          totalTables: tableNames.length,
          tableProgress: 1.0,
          tableExportedRows: lineCount,
          tableTotalRows: lineCount,
        );
      } catch (e) {
        tableResults.add(
          BulkExportTableResult(
            tableName: tableName,
            fileName: fileName,
            success: false,
            errorMessage: e.toString(),
          ),
        );

        onProgress?.call(
          currentTable: tableName,
          tableIndex: i,
          totalTables: tableNames.length,
          tableProgress: 0.0,
          tableExportedRows: 0,
          tableTotalRows: 0,
        );
      }
    }

    final failedCount = tableResults.where((r) => !r.success).length;

    return BulkExportResult(
      success: failedCount == 0,
      tableResults: tableResults,
      totalExportedRows: totalExported,
      errorMessage: failedCount > 0
          ? '$failedCount Tabellen konnten nicht exportiert werden'
          : null,
    );
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

// ---------------------------------------------------------------------------
// Bulk Export Result Classes
// ---------------------------------------------------------------------------

/// Ergebnis eines einzelnen Tabellen-Exports innerhalb eines Bulk-Exports.
class BulkExportTableResult {
  final String tableName;
  final String fileName;
  final bool success;
  final int exportedRows;
  final String? errorMessage;

  const BulkExportTableResult({
    required this.tableName,
    required this.fileName,
    required this.success,
    this.exportedRows = 0,
    this.errorMessage,
  });
}

/// Ergebnis eines Bulk-Exports (mehrere Tabellen).
class BulkExportResult {
  final bool success;
  final List<BulkExportTableResult> tableResults;
  final int totalExportedRows;
  final String? errorMessage;

  const BulkExportResult({
    required this.success,
    required this.tableResults,
    this.totalExportedRows = 0,
    this.errorMessage,
  });
}
