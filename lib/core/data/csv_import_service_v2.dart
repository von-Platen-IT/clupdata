import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import 'import_logger.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Datentyp einer Datenbankspalte.
enum ColumnDataType { integer, real, text, boolean, datetime }

/// Import-Modus: Überschreiben löscht vorhandene Daten, Anfügen fügt hinzu.
enum ImportMode { overwrite, append }

// ---------------------------------------------------------------------------
// Data Classes
// ---------------------------------------------------------------------------

/// Schema-Information einer Datenbankspalte.
class ColumnSchema {
  final String name;
  final ColumnDataType dataType;
  final bool isNullable;
  final bool isPrimaryKey;
  final String? defaultValue;

  const ColumnSchema({
    required this.name,
    required this.dataType,
    required this.isNullable,
    required this.isPrimaryKey,
    this.defaultValue,
  });

  /// Spalte ist für den Import relevant (kein AutoIncrement-PK).
  bool get isImportable => !isPrimaryKey;

  /// Spalte muss in der CSV vorhanden sein (NOT NULL ohne Default, nicht PK).
  bool get isRequired => !isNullable && !isPrimaryKey && defaultValue == null;
}

/// Schema-Information einer Datenbanktabelle.
class TableSchema {
  final String sqlTableName;
  final String displayName;
  final List<ColumnSchema> columns;

  const TableSchema({
    required this.sqlTableName,
    required this.displayName,
    required this.columns,
  });

  /// Spalten, die für den Import relevant sind (ohne PK).
  List<ColumnSchema> get importableColumns =>
      columns.where((c) => c.isImportable).toList();

  /// Pflichtspalten ohne Default (müssen in der CSV vorhanden sein).
  List<ColumnSchema> get requiredColumns =>
      columns.where((c) => c.isRequired).toList();

  /// Namen aller importierbaren Spalten.
  List<String> get importableColumnNames =>
      importableColumns.map((c) => c.name).toList();

  /// Namen aller Pflichtspalten.
  List<String> get requiredColumnNames =>
      requiredColumns.map((c) => c.name).toList();
}

/// Ergebnis einer einzelnen Import-Operation.
class ImportRowResult {
  final int rowIndex;
  final bool success;
  final String? errorMessage;

  const ImportRowResult({
    required this.rowIndex,
    required this.success,
    this.errorMessage,
  });
}

/// Ergebnis des CSV-Imports.
class CsvImportResult {
  final bool success;
  final int importedRows;
  final int failedRows;
  final List<String> errors;
  final List<ImportRowResult> rowResults;
  final String? errorMessage;
  final ImportLogger? logger;

  const CsvImportResult({
    required this.success,
    this.importedRows = 0,
    this.failedRows = 0,
    this.errors = const [],
    this.rowResults = const [],
    this.errorMessage,
    this.logger,
  });
}

/// Ergebnis einer Batch-Import-Operation.
class BatchImportResult {
  final int successCount;
  final int failureCount;
  final Map<int, String> failedRows; // Index -> Error Message

  const BatchImportResult({
    required this.successCount,
    required this.failureCount,
    required this.failedRows,
  });
}

/// Konvertierungsoptionen für CSV-Daten.
class CsvConversionOptions {
  /// NULL-Platzhalter die als SQL NULL interpretiert werden.
  /// WICHTIG: Leerer String '' ist NICHT in der Liste, damit NOT NULL Spalten
  /// bei leeren Strings fehlschlagen statt NULL zu akzeptieren.
  final List<String> nullPlaceholders;

  /// Datumsformate die erkannt werden sollen (in Reihenfolge der Prüfung).
  final List<String> dateFormats;

  /// Dezimal-Trennzeichen für europäische Zahlen.
  final bool europeanNumberFormat;

  const CsvConversionOptions({
    this.nullPlaceholders = const ['<NULL>', 'NULL', 'N/A', 'null', 'n/a', '-'],
    this.dateFormats = const [
      'dd.MM.yyyy',
      'd.M.yyyy',
      'M/d/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
    ],
    this.europeanNumberFormat = true,
  });

  static const defaultOptions = CsvConversionOptions();
}

/// Callback für Import-Progress.
typedef ImportProgressCallback =
    void Function(int processedRows, int totalRows);

/// Callback für Validierungs-Progress.
typedef ValidationProgressCallback = void Function(int processedRows);

// ---------------------------------------------------------------------------
// CSV Streaming Parser
// ---------------------------------------------------------------------------

/// Streaming CSV Parser für große Dateien.
///
/// Liest die Datei in Chunks und parsed zeilenweise, um Memory-Spikes zu vermeiden.
class CsvStreamingParser {
  final String fieldDelimiter;
  final String? rowDelimiter;

  const CsvStreamingParser({this.fieldDelimiter = ';', this.rowDelimiter});

  /// Erkennt das Trennzeichen automatisch aus einer Probe.
  static String detectDelimiter(String sample) {
    final lines = sample.split('\n');
    if (lines.isEmpty) return ';';

    final firstLine = lines.first;

    final semicolonCount = ';'.allMatches(firstLine).length;
    final commaCount = ','.allMatches(firstLine).length;
    final tabCount = '\t'.allMatches(firstLine).length;

    if (semicolonCount >= commaCount && semicolonCount >= tabCount) return ';';
    if (commaCount >= semicolonCount && commaCount >= tabCount) return ',';
    if (tabCount > 0) return '\t';
    return ';';
  }

  /// Parst eine CSV-Datei als Stream von Zeilen.
  ///
  /// [onProgress] wird nach jeder gelesenen Zeile aufgerufen.
  Stream<List<String>> parseFile(
    String filePath, {
    void Function(int lineCount)? onProgress,
  }) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Datei nicht gefunden', filePath);
    }

    final csvCodec = Csv(fieldDelimiter: fieldDelimiter);

    // Datei einlesen (für große Dateien später: chunked reading)
    var content = await file.readAsString();

    // UTF-8 BOM entfernen (alle gängigen Encodings)
    if (content.startsWith('\ufeff')) {
      content = content.substring(1);
    } else if (content.startsWith('ï»¿')) {
      content = content.substring(3);
    } else if (content.codeUnits.length >= 3 &&
        content.codeUnits[0] == 0xEF &&
        content.codeUnits[1] == 0xBB &&
        content.codeUnits[2] == 0xBF) {
      content = content.substring(3);
    }

    final rows = csvCodec.decoder.convert(content);
    var lineCount = 0;

    for (final row in rows) {
      lineCount++;
      // Trim + BOM aus jedem Field entfernen
      final cleaned = row.map((cell) {
        var str = cell.toString().trim();
        // BOM aus erstem Feld entfernen falls noch vorhanden
        str = str.replaceFirst(RegExp(r'^[\ufeffï»¿]+'), '');
        return str;
      }).toList();
      yield cleaned;
      onProgress?.call(lineCount);
    }
  }

  /// Parst nur den Header einer CSV-Datei.
  Future<List<String>?> parseHeader(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    // Nur die ersten paar KB lesen für den Header
    final raf = await file.open();
    final buffer = await raf.read(4096); // 4KB sollten für den Header reichen
    await raf.close();

    var content = String.fromCharCodes(buffer);

    // UTF-8 BOM entfernen
    if (content.startsWith('\ufeff')) {
      content = content.substring(1);
    }

    // Erste Zeile extrahieren
    final firstNewline = content.indexOf('\n');
    final headerLine = firstNewline > 0
        ? content.substring(0, firstNewline)
        : content;

    final csvCodec = Csv(fieldDelimiter: fieldDelimiter);
    final rows = csvCodec.decoder.convert(headerLine);

    if (rows.isEmpty) return null;
    return rows.first.map((h) => h.toString().trim()).toList();
  }
}

// ---------------------------------------------------------------------------
// Data Type Converter
// ---------------------------------------------------------------------------

/// Konvertiert CSV-String-Werte in typisierte Werte für SQLite.
class CsvDataConverter {
  final CsvConversionOptions options;

  const CsvDataConverter([this.options = CsvConversionOptions.defaultOptions]);

  /// Prüft ob ein Wert als NULL interpretiert werden soll.
  bool isNullValue(String? value) {
    if (value == null) return true;
    return options.nullPlaceholders.contains(value.trim());
  }

  /// Konvertiert einen String-Wert basierend auf dem Ziel-Datentyp.
  dynamic convert(String? value, ColumnDataType targetType) {
    if (isNullValue(value)) return null;

    final trimmed = value!.trim();
    if (trimmed.isEmpty) return null;

    switch (targetType) {
      case ColumnDataType.integer:
        return _parseInteger(trimmed);
      case ColumnDataType.real:
        return _parseReal(trimmed);
      case ColumnDataType.text:
        return trimmed;
      case ColumnDataType.boolean:
        return _parseBoolean(trimmed);
      case ColumnDataType.datetime:
        return _parseDateTime(trimmed);
    }
  }

  /// Parst einen Integer-Wert.
  int? _parseInteger(String value) {
    // Entferne Tausender-Trennzeichen
    final cleaned = value.replaceAll('.', '').replaceAll(',', '');
    return int.tryParse(cleaned);
  }

  /// Parst einen Double-Wert (unterstützt europäisches Format).
  double? _parseReal(String value) {
    if (options.europeanNumberFormat) {
      // Europäisch: 1.234,56 -> 1234.56
      // Oder: 1234,56 -> 1234.56
      if (value.contains(',') && value.contains('.')) {
        // Beide vorhanden: 1.234,56
        final cleaned = value.replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(cleaned);
      } else if (value.contains(',')) {
        // Nur Komma: 1234,56
        final cleaned = value.replaceAll(',', '.');
        return double.tryParse(cleaned);
      }
    }
    // Standard: 1234.56
    return double.tryParse(value);
  }

  /// Parst einen Boolean-Wert.
  bool? _parseBoolean(String value) {
    final lower = value.toLowerCase().trim();
    if (['1', 'true', 'yes', 'ja', 'wahr'].contains(lower)) return true;
    if (['0', 'false', 'no', 'nein', 'falsch'].contains(lower)) return false;
    return null;
  }

  /// Parst ein Datum (versucht mehrere Formate).
  DateTime? _parseDateTime(String value) {
    for (final format in options.dateFormats) {
      try {
        return DateFormat(format).parseStrict(value);
      } catch (_) {
        // Nächstes Format probieren
      }
    }

    // ISO 8601 als Fallback
    try {
      return DateTime.parse(value);
    } catch (_) {}

    return null;
  }

  /// Validiert ob ein Wert zum Zieltyp passt.
  bool isValid(String? value, ColumnDataType targetType) {
    if (isNullValue(value)) return true;
    return convert(value, targetType) != null;
  }
}

// ---------------------------------------------------------------------------
// Main Service
// ---------------------------------------------------------------------------

/// Zentraler Service für CSV-Import mit Streaming, Batching und Fehler-Resilienz.
class CsvImportServiceV2 {
  CsvImportServiceV2._();

  /// Anzeigenamen für Tabellen.
  static const _tableDisplayNames = <String, String>{
    'bemerkung': 'Bemerkungen',
    'stammdaten': 'Stammdaten',
    'preis': 'Preise',
    'leistung': 'Leistungen',
    'mitglied': 'Mitglieder',
    'waren': 'Waren',
    'beitrag': 'Beiträge',
    'beitrag_status_verlauf': 'Beitragsstatus-Verlauf',
    'rechnung': 'Rechnungen',
    'rechnung_position': 'Rechnungspositionen',
  };

  /// DateTime-Spalten pro Tabelle.
  static const _dateTimeColumnsByTable = <String, List<String>>{
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
    'beitrag_status_verlauf': ['geaendert_am'],
    'rechnung': [
      'rechnungsdatum',
      'faelligkeitsdatum',
      'bezahlt_am',
      'erstellt_am',
    ],
    'rechnung_position': ['erstellt_am'],
    'waren': ['gueltig_von', 'gueltig_bis'],
    'preis': ['gueltig_ab', 'gueltig_bis'],
  };

  /// Boolean-Spalten pro Tabelle.
  static const _booleanColumnsByTable = <String, List<String>>{
    'stammdaten': ['mwst_pflicht'],
  };

  // -------------------------------------------------------------------------
  // Schema Handling
  // -------------------------------------------------------------------------

  /// Liefert alle importierbaren Tabellen mit ihren Schemas.
  static Future<List<TableSchema>> getImportableTables(AppDatabase db) async {
    final schemas = <TableSchema>[];

    for (final tableInfo in db.allTables) {
      final sqlName = tableInfo.actualTableName;
      final displayName = _tableDisplayNames[sqlName] ?? _humanize(sqlName);

      final columns = await _readColumnSchemas(db, sqlName);

      schemas.add(
        TableSchema(
          sqlTableName: sqlName,
          displayName: displayName,
          columns: columns,
        ),
      );
    }

    return schemas;
  }

  /// Liest Spalten-Schema via PRAGMA table_info.
  static Future<List<ColumnSchema>> _readColumnSchemas(
    AppDatabase db,
    String tableName,
  ) async {
    final rows = await db
        .customSelect(
          'PRAGMA table_info($tableName)',
          readsFrom: {
            db.allTables.firstWhere((t) => t.actualTableName == tableName),
          },
        )
        .get();

    final dateTimeCols = _dateTimeColumnsByTable[tableName] ?? [];
    final boolCols = _booleanColumnsByTable[tableName] ?? [];

    return rows.map((row) {
      final name = row.read<String>('name');
      final type = row.read<String>('type');
      final notNull = row.read<int>('notnull') == 1;
      final pk = row.read<int>('pk') > 0;
      final defaultValue = row.read<String?>('dflt_value');

      final dataType = _determineDataType(name, type, dateTimeCols, boolCols);

      return ColumnSchema(
        name: name,
        dataType: dataType,
        isNullable: !notNull,
        isPrimaryKey: pk,
        defaultValue: defaultValue,
      );
    }).toList();
  }

  /// Bestimmt den Datentyp.
  static ColumnDataType _determineDataType(
    String columnName,
    String sqlType,
    List<String> dateTimeCols,
    List<String> boolCols,
  ) {
    if (dateTimeCols.contains(columnName)) return ColumnDataType.datetime;
    if (boolCols.contains(columnName)) return ColumnDataType.boolean;

    final upper = sqlType.toUpperCase();
    if (upper == 'INTEGER') return ColumnDataType.integer;
    if (upper == 'REAL') return ColumnDataType.real;
    return ColumnDataType.text;
  }

  // -------------------------------------------------------------------------
  // Analysis & Validation
  // -------------------------------------------------------------------------

  /// Analysiert eine CSV-Datei ohne Import.
  ///
  /// Liefert Informationen über Header, Zeilenanzahl, erkanntes Trennzeichen.
  static Future<Map<String, dynamic>> analyzeFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Datei nicht gefunden', filePath);
    }

    // Erste 4KB lesen für Header-Analyse
    final raf = await file.open();
    final buffer = await raf.read(4096);
    await raf.close();

    var sample = String.fromCharCodes(buffer);
    if (sample.startsWith('\ufeff')) {
      sample = sample.substring(1);
    }

    final delimiter = CsvStreamingParser.detectDelimiter(sample);

    // Gesamtzeilen zählen (approximativ für große Dateien)
    final totalBytes = await file.length();
    final lines = sample.split('\n').length;
    // Vermeide Division durch Null bei leeren Buffern
    final estimatedTotalLines = buffer.isNotEmpty
        ? (totalBytes / buffer.length * lines).round()
        : lines;

    // Header parsen
    final parser = CsvStreamingParser(fieldDelimiter: delimiter);
    final headers = await parser.parseHeader(filePath) ?? [];

    return {
      'delimiter': delimiter,
      'headers': headers,
      'headerCount': headers.length,
      'estimatedRows': estimatedTotalLines,
      'fileSize': totalBytes,
    };
  }

  /// Validiert eine CSV-Datei gegen das Tabellen-Schema.
  ///
  /// Liefert eine Liste von Validierungsfehlern pro Zeile.
  static Stream<ValidationResult> validateFile(
    String filePath,
    TableSchema schema, {
    CsvConversionOptions options = CsvConversionOptions.defaultOptions,
    ValidationProgressCallback? onProgress,
  }) async* {
    final analysis = await analyzeFile(filePath);
    final delimiter = analysis['delimiter'] as String;
    final headers = (analysis['headers'] as List).cast<String>();

    // Column Mapping erstellen
    final columnMapping = _buildColumnMapping(headers, schema);

    final parser = CsvStreamingParser(fieldDelimiter: delimiter);
    final converter = CsvDataConverter(options);

    var isFirstRow = true;
    var rowIndex = 0;

    await for (final row in parser.parseFile(filePath)) {
      if (isFirstRow) {
        isFirstRow = false;
        continue; // Header überspringen
      }

      rowIndex++;
      final errors = <String>[];

      for (final entry in columnMapping.entries) {
        final colIndex = entry.key;
        final column = entry.value;

        final value = colIndex < row.length ? row[colIndex] : null;

        if (!converter.isValid(value, column.dataType)) {
          errors.add(
            'Spalte "${column.name}": '
            '"${value ?? ''}" ist kein gültiger ${_dataTypeLabel(column.dataType)}',
          );
        }
      }

      yield ValidationResult(
        rowIndex: rowIndex,
        isValid: errors.isEmpty,
        errors: errors,
      );

      onProgress?.call(rowIndex);
    }
  }

  // -------------------------------------------------------------------------
  // Import
  // -------------------------------------------------------------------------

  /// Importiert eine CSV-Datei mit Batching und Fehler-Resilienz.
  ///
  /// [batchSize]: Anzahl der Zeilen pro Batch (Default: 100)
  /// [onProgress]: Callback mit (importedRows, totalRows)
  /// [onRowError]: Callback für fehlgeschlagene Zeilen
  static Future<CsvImportResult> importFile(
    String filePath,
    TableSchema schema,
    ImportMode mode,
    AppDatabase db, {
    int batchSize = 100,
    CsvConversionOptions options = CsvConversionOptions.defaultOptions,
    ImportProgressCallback? onProgress,
    void Function(int rowIndex, String error)? onRowError,
  }) async {
    final stopwatch = Stopwatch()..start();
    final logger = ImportLogger();

    try {
      logger.info(
        phase: ImportPhase.initialization,
        message: 'CSV Import gestartet (V2)',
        context: {
          'filePath': filePath,
          'tableName': schema.sqlTableName,
          'mode': mode.toString(),
        },
      );

      // Datei analysieren
      final analysis = await analyzeFile(filePath);
      final delimiter = analysis['delimiter'] as String;
      final headers = (analysis['headers'] as List).cast<String>();
      final estimatedRows = analysis['estimatedRows'] as int;

      logger.info(
        phase: ImportPhase.fileAnalysis,
        message: 'Datei analysiert',
        context: {
          'delimiter': delimiter,
          'headers': headers.length,
          'estimatedRows': estimatedRows,
        },
      );

      // Column Mapping
      final columnMapping = _buildColumnMapping(headers, schema);
      if (columnMapping.isEmpty) {
        logger.critical(
          phase: ImportPhase.schemaMapping,
          message: 'Keine übereinstimmenden Spalten',
        );
        return CsvImportResult(
          success: false,
          errorMessage: 'Keine übereinstimmenden Spalten gefunden',
          logger: logger,
        );
      }

      final parser = CsvStreamingParser(fieldDelimiter: delimiter);
      final converter = CsvDataConverter(options);

      // Bei Überschreiben: Daten löschen
      if (mode == ImportMode.overwrite) {
        await db.customStatement('DELETE FROM ${schema.sqlTableName}');
      }

      var importedCount = 0;
      var failedCount = 0;
      final rowResults = <ImportRowResult>[];
      var currentBatch = <Map<String, dynamic>>[];

      var isFirstRow = true;
      var rowIndex = 0;

      await for (final row in parser.parseFile(filePath)) {
        if (isFirstRow) {
          isFirstRow = false;
          continue;
        }

        rowIndex++;

        // Zeile in Map konvertieren
        final rowData = <String, dynamic>{};
        String? errorMessage;

        try {
          for (final entry in columnMapping.entries) {
            final colIndex = entry.key;
            final column = entry.value;

            final value = colIndex < row.length ? row[colIndex] : null;
            final converted = converter.convert(value, column.dataType);

            if (converted != null || column.isNullable) {
              rowData[column.name] = converted;
            } else if (column.isRequired) {
              throw Exception('Pflichtfeld "${column.name}" fehlt');
            }
          }

          currentBatch.add(rowData);
        } catch (e) {
          errorMessage = e.toString();
          failedCount++;

          rowResults.add(
            ImportRowResult(
              rowIndex: rowIndex,
              success: false,
              errorMessage: errorMessage,
            ),
          );

          logger.error(
            phase: ImportPhase.dataValidation,
            message: 'Zeile konnte nicht konvertiert werden',
            context: {'rowIndex': rowIndex},
            error: e,
          );

          onRowError?.call(rowIndex, errorMessage);
        }

        // Batch ausführen wenn voll
        if (currentBatch.length >= batchSize) {
          final batchResult = await _executeBatch(
            db,
            schema.sqlTableName,
            columnMapping.values.toList(),
            currentBatch,
            logger,
          );
          importedCount += batchResult.successCount;
          failedCount += batchResult.failureCount;
          currentBatch = [];

          onProgress?.call(importedCount, estimatedRows);
        }
      }

      // Restlichen Batch ausführen
      if (currentBatch.isNotEmpty) {
        final batchResult = await _executeBatch(
          db,
          schema.sqlTableName,
          columnMapping.values.toList(),
          currentBatch,
          logger,
        );
        importedCount += batchResult.successCount;
        failedCount += batchResult.failureCount;
      }

      stopwatch.stop();

      logger.info(
        phase: ImportPhase.completion,
        message: 'Import abgeschlossen',
        context: {
          'duration': '${stopwatch.elapsed.inSeconds}s',
          'imported': importedCount,
          'failed': failedCount,
        },
      );

      return CsvImportResult(
        success: failedCount == 0 || importedCount > 0,
        importedRows: importedCount,
        failedRows: failedCount,
        rowResults: rowResults,
        errors: failedCount > 0
            ? ['$failedCount Zeilen konnten nicht importiert werden']
            : [],
        logger: logger,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      logger.critical(
        phase: ImportPhase.completion,
        message: 'Import fehlgeschlagen',
        error: e,
        stackTrace: stackTrace,
      );
      return CsvImportResult(
        success: false,
        errorMessage: 'Import fehlgeschlagen: $e',
        logger: logger,
      );
    }
  }

  /// Führt einen Batch von Insert-Operationen fehler-resilient aus.
  ///
  /// Jede Zeile wird einzeln in einer eigenen Transaktion verarbeitet.
  /// Fehlerhafte Zeilen werden übersprungen, der Import läuft weiter.
  static Future<BatchImportResult> _executeBatch(
    AppDatabase db,
    String tableName,
    List<ColumnSchema> columns,
    List<Map<String, dynamic>> rows,
    ImportLogger logger,
  ) async {
    var successCount = 0;
    var failureCount = 0;
    final failedRows = <int, String>{};

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      try {
        final insertColumns = <String>[];
        final values = <dynamic>[];

        for (final entry in row.entries) {
          final colName = entry.key;
          final value = entry.value;

          insertColumns.add(colName);

          final colSchema = columns.firstWhere((c) => c.name == colName);

          try {
            // Wert für SQLite konvertieren (Boolean -> int, etc.)
            final sqlValue = _toSqlValue(value, colSchema.dataType);
            values.add(sqlValue);
          } catch (e) {
            logger.error(
              phase: ImportPhase.dataImport,
              message: 'Typ-Konvertierung fehlgeschlagen',
              context: {
                'batchIndex': i,
                'column': colName,
                'value': value,
                'expectedType': colSchema.dataType.toString(),
              },
              error: e,
            );
            throw Exception('Spalte "$colName": $e');
          }
        }

        if (insertColumns.isEmpty) {
          throw Exception('Keine Daten zum Importieren');
        }

        final placeholders = insertColumns.map((_) => '?').join(', ');
        final sql =
            'INSERT INTO $tableName '
            '(${insertColumns.join(', ')}) VALUES ($placeholders)';

        // Jede Zeile in eigener Transaktion = atomare Operation
        await db.transaction(() async {
          await db.customStatement(sql, values);
        });

        successCount++;

        logger.debug(
          phase: ImportPhase.dataImport,
          message: 'Zeile erfolgreich importiert',
          context: {'batchIndex': i, 'columns': insertColumns.length},
        );
      } catch (e, stackTrace) {
        failureCount++;
        failedRows[i] = e.toString();

        logger.error(
          phase: ImportPhase.dataImport,
          message: 'Import der Zeile fehlgeschlagen',
          context: {'batchIndex': i, 'rowData': row},
          error: e,
          stackTrace: stackTrace,
        );

        // Weiter mit nächster Zeile
        continue;
      }
    }

    return BatchImportResult(
      successCount: successCount,
      failureCount: failureCount,
      failedRows: failedRows,
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Erstellt das Mapping: CSV-Index -> ColumnSchema
  ///
  /// Versucht intelligentes Matching:
  /// 1. Exakte Übereinstimmung (case-insensitive)
  /// 2. Normalisierung: "Brutto (€)" → "brutto", "Telefon 1" → "telefon1"
  static Map<int, ColumnSchema> _buildColumnMapping(
    List<String> headers,
    TableSchema schema,
  ) {
    final mapping = <int, ColumnSchema>{};
    final importable = schema.importableColumns;

    for (var i = 0; i < headers.length; i++) {
      var header = headers[i];

      // UTF-8 BOM aus erstem Header entfernen
      if (i == 0) {
        header = header.replaceFirst(RegExp(r'^[\ufeffï»¿]+'), '');
      }

      final normalized = _normalizeColumnName(header);

      for (final col in importable) {
        final colNormalized = _normalizeColumnName(col.name);

        if (colNormalized == normalized) {
          mapping[i] = col;
          break;
        }
      }
    }

    return mapping;
  }

  /// Normalisiert einen Spaltennamen für Matching.
  ///
  /// Beispiele:
  /// - "Name" → "name"
  /// - "Telefon 1" → "telefon1"
  /// - "Brutto (€)" → "brutto"
  /// - "E-Mail" → "email"
  static String _normalizeColumnName(String name) {
    return name
        .toLowerCase()
        .trim()
        // Sonderzeichen entfernen
        .replaceAll(RegExp(r'[€$%\(\)\[\]\{\}<>]'), '')
        // Bindestriche durch Unterstriche
        .replaceAll('-', '_')
        // Leerzeichen entfernen
        .replaceAll(RegExp(r'\s+'), '')
        // Umlaute normalisieren
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
  }

  /// Konvertiert einen Wert in ein SQLite-kompatibles Format.
  ///
  /// Gibt Rohwerte zurück (nicht Variable-Objekte), da customStatement()
  /// direkte Werte erwartet.
  ///
  /// Wirft [Exception] wenn der Wert nicht zum erwarteten Typ passt.
  static dynamic _toSqlValue(dynamic value, ColumnDataType type) {
    // NULL-Werte explizit behandeln
    if (value == null) {
      return null;
    }

    switch (type) {
      case ColumnDataType.integer:
        if (value is! int) {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet int, erhalten ${value.runtimeType} ($value)',
          );
        }
        return value;

      case ColumnDataType.real:
        if (value is! double) {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet double, erhalten ${value.runtimeType} ($value)',
          );
        }
        return value;

      case ColumnDataType.text:
        return value.toString();

      case ColumnDataType.boolean:
        // Boolean wird als Integer (0/1) in SQLite gespeichert
        if (value is bool) {
          return value ? 1 : 0;
        } else if (value is int) {
          return value;
        } else {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet bool oder int, erhalten ${value.runtimeType} ($value)',
          );
        }

      case ColumnDataType.datetime:
        if (value is! DateTime) {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet DateTime, erhalten ${value.runtimeType} ($value)',
          );
        }
        // DateTime wird als Unix-Timestamp (Sekunden seit Epoch) gespeichert
        return value.millisecondsSinceEpoch ~/ 1000;
    }
  }

  /// Erstellt eine Drift-Variable aus einem Wert mit NULL-Safety.
  ///
  /// @deprecated Verwende stattdessen _toSqlValue() für customStatement().
  /// Wirft [Exception] wenn der Wert nicht zum erwarteten Typ passt.
  static Variable _toVariable(dynamic value, ColumnDataType type) {
    // NULL-Werte explizit behandeln
    if (value == null) {
      return const Variable(null);
    }

    switch (type) {
      case ColumnDataType.integer:
        if (value is! int) {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet int, erhalten ${value.runtimeType} ($value)',
          );
        }
        return Variable<int>(value);

      case ColumnDataType.real:
        if (value is! double) {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet double, erhalten ${value.runtimeType} ($value)',
          );
        }
        return Variable<double>(value);

      case ColumnDataType.text:
        return Variable<String>(value.toString());

      case ColumnDataType.boolean:
        if (value is bool) {
          return Variable<int>(value ? 1 : 0);
        } else if (value is int) {
          return Variable<int>(value);
        } else {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet bool oder int, erhalten ${value.runtimeType} ($value)',
          );
        }

      case ColumnDataType.datetime:
        if (value is! DateTime) {
          throw Exception(
            'Spalten-Typ-Fehler: Erwartet DateTime, erhalten ${value.runtimeType} ($value)',
          );
        }
        return Variable<DateTime>(value);
    }
  }

  /// Sanitisiert Header-Namen für SQL-Kompatibilität.
  static String _sanitizeHeader(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Menschenlesbarer Name.
  static String _humanize(String name) {
    return name
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Anzeigelabel für Datentyp.
  static String _dataTypeLabel(ColumnDataType type) {
    switch (type) {
      case ColumnDataType.integer:
        return 'Ganzzahl';
      case ColumnDataType.real:
        return 'Zahl';
      case ColumnDataType.text:
        return 'Text';
      case ColumnDataType.boolean:
        return 'Wahrheitswert';
      case ColumnDataType.datetime:
        return 'Datum/Zeit';
    }
  }
}

/// Ergebnis einer Validierungs-Operation.
class ValidationResult {
  final int rowIndex;
  final bool isValid;
  final List<String> errors;

  const ValidationResult({
    required this.rowIndex,
    required this.isValid,
    this.errors = const [],
  });
}
