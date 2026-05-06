import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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
  final Map<int, String> failedRows;

  const BatchImportResult({
    required this.successCount,
    required this.failureCount,
    required this.failedRows,
  });
}

/// Konvertierungsoptionen für CSV-Daten.
class CsvConversionOptions {
  final List<String> nullPlaceholders;
  final List<String> dateFormats;
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
  Stream<List<String>> parseFile(
    String filePath, {
    void Function(int lineCount)? onProgress,
  }) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Datei nicht gefunden', filePath);
    }

    final csvCodec = Csv(fieldDelimiter: fieldDelimiter);

    var content = await file.readAsString();

    // UTF-8 BOM entfernen
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
      final cleaned = row.map((cell) {
        var str = cell.toString().trim();
        str = str.replaceFirst(RegExp(r'^[\ufeffï»¿]+'), '');
        return str;
      }).toList();
      yield cleaned;
      onProgress?.call(lineCount);
    }
  }

  /// Parst nur den Header einer CSV-Datei.
  ///
  /// Entfernt zuverlässig UTF-8 BOM (0xEF, 0xBB, 0xBF) aus dem Dateianfang,
  /// bevor der CSV-Parser den Header interpretiert.
  Future<List<String>?> parseHeader(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final raf = await file.open();
    final buffer = await raf.read(4096);
    await raf.close();

    // UTF-8 Dekodierung mit BOM-Entfernung
    var content = utf8.decode(buffer, allowMalformed: true);

    // BOM auf allen Ebenen entfernen
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    } else if (content.startsWith('\ufeff')) {
      content = content.substring(1);
    }

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

  bool isNullValue(String? value) {
    if (value == null) return true;
    return options.nullPlaceholders.contains(value.trim());
  }

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

  int? _parseInteger(String value) {
    final cleaned = value.replaceAll('.', '').replaceAll(',', '');
    return int.tryParse(cleaned);
  }

  double? _parseReal(String value) {
    if (options.europeanNumberFormat) {
      if (value.contains(',') && value.contains('.')) {
        final cleaned = value.replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(cleaned);
      } else if (value.contains(',')) {
        final cleaned = value.replaceAll(',', '.');
        return double.tryParse(cleaned);
      }
    }
    return double.tryParse(value);
  }

  bool? _parseBoolean(String value) {
    final lower = value.toLowerCase().trim();
    if (['1', 'true', 'yes', 'ja', 'wahr'].contains(lower)) return true;
    if (['0', 'false', 'no', 'nein', 'falsch'].contains(lower)) return false;
    return null;
  }

  DateTime? _parseDateTime(String value) {
    for (final format in options.dateFormats) {
      try {
        return DateFormat(format).parseStrict(value);
      } catch (_) {}
    }
    try {
      return DateTime.parse(value);
    } catch (_) {}
    return null;
  }

  bool isValid(String? value, ColumnDataType targetType) {
    if (isNullValue(value)) return true;
    return convert(value, targetType) != null;
  }
}

// ---------------------------------------------------------------------------
// UUID-Mapping für FK-Auflösung
// ---------------------------------------------------------------------------

/// Verwaltet das Mapping von UUID → lokaler ID für alle Tabellen.
/// Wird vor dem Import befüllt, um performante FK-Auflösung zu ermöglichen.
class UuidMapping {
  final Map<String, Map<String, int>> _uuidToId = {};
  final Map<String, Map<int, String>> _idToUuid = {};

  /// Lädt alle UUID→ID Mappings aus der Datenbank.
  Future<void> loadFromDatabase(AppDatabase db) async {
    final tables = [
      'bemerkung',
      'stammdaten',
      'preis',
      'leistung',
      'mitglied',
      'waren',
      'beitrag',
      'beitrag_status_verlauf',
      'rechnung',
      'rechnung_position',
    ];

    for (final table in tables) {
      try {
        final rows = await db.customSelect('SELECT id, uuid FROM $table').get();
        _uuidToId[table] = {
          for (final row in rows) row.read<String>('uuid'): row.read<int>('id'),
        };
        _idToUuid[table] = {
          for (final row in rows) row.read<int>('id'): row.read<String>('uuid'),
        };
      } catch (_) {
        // Tabelle existiert noch nicht (bei erstmaligem Import)
        _uuidToId[table] = {};
        _idToUuid[table] = {};
      }
    }
  }

  /// Gibt die lokale ID für eine UUID zurück, oder null.
  int? getLocalId(String tableName, String uuid) {
    return _uuidToId[tableName]?[uuid];
  }

  /// Gibt die UUID für eine lokale ID zurück, oder null.
  String? getUuid(String tableName, int id) {
    return _idToUuid[tableName]?[id];
  }

  /// Fügt ein neues Mapping hinzu (nach erfolgreichem Insert).
  void addMapping(String tableName, String uuid, int localId) {
    _uuidToId.putIfAbsent(tableName, () => {})[uuid] = localId;
    _idToUuid.putIfAbsent(tableName, () => {})[localId] = uuid;
  }

  /// Prüft ob eine UUID bereits in der Datenbank existiert.
  bool hasUuid(String tableName, String uuid) {
    return _uuidToId[tableName]?.containsKey(uuid) ?? false;
  }
}

// ---------------------------------------------------------------------------
// Main Service
// ---------------------------------------------------------------------------

/// Zentraler Service für CSV-Import mit UUID-basiertem Upsert.
///
/// Features:
/// - UUID-basiertes Upsert (INSERT ... ON CONFLICT(uuid) DO UPDATE)
/// - FK-Auflösung über UUID-Mapping im RAM
/// - Korrekte Import-Reihenfolge (FK-Abhängigkeiten)
/// - Streaming, Batching und Fehler-Resilienz
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

  /// Import-Reihenfolge (FK-Abhängigkeiten).
  static const _importOrder = [
    'bemerkung',
    'stammdaten',
    'preis',
    'leistung',
    'mitglied',
    'waren',
    'beitrag',
    'beitrag_status_verlauf',
    'rechnung',
    'rechnung_position',
  ];

  /// Mapping: CSV-Header-Name (z.B. "mitglied_uuid") → Ziel-Tabellenname
  static const _fkUuidMapping = <String, String>{
    'bemerkung_uuid': 'bemerkung',
    'preis_uuid': 'preis',
    'leistung_uuid': 'leistung',
    'mitglied_uuid': 'mitglied',
    'waren_uuid': 'waren',
    'beitrag_uuid': 'beitrag',
    'rechnung_uuid': 'rechnung',
  };

  /// DateTime-Spalten pro Tabelle.
  static const _dateTimeColumnsByTable = <String, List<String>>{
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

    return rows.map((row) {
      final name = row.read<String>('name');
      final type = row.read<String>('type');
      final notNull = row.read<int>('notnull') == 1;
      final pk = row.read<int>('pk') > 0;
      final defaultValue = row.read<String?>('dflt_value');

      final dataType = _determineDataType(name, type, dateTimeCols);

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
  ) {
    if (dateTimeCols.contains(columnName)) return ColumnDataType.datetime;

    final upper = sqlType.toUpperCase();
    if (upper == 'INTEGER') return ColumnDataType.integer;
    if (upper == 'REAL') return ColumnDataType.real;
    return ColumnDataType.text;
  }

  // -------------------------------------------------------------------------
  // Analysis & Validation
  // -------------------------------------------------------------------------

  /// Analysiert eine CSV-Datei ohne Import.
  static Future<Map<String, dynamic>> analyzeFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Datei nicht gefunden', filePath);
    }

    final raf = await file.open();
    final buffer = await raf.read(4096);
    await raf.close();

    // UTF-8 Dekodierung mit BOM-Entfernung
    var sample = utf8.decode(buffer, allowMalformed: true);
    if (sample.startsWith('\uFEFF')) {
      sample = sample.substring(1);
    } else if (sample.startsWith('\ufeff')) {
      sample = sample.substring(1);
    }

    final delimiter = CsvStreamingParser.detectDelimiter(sample);

    final totalBytes = await file.length();
    final lines = sample.split('\n').length;
    final estimatedTotalLines = buffer.isNotEmpty
        ? (totalBytes / buffer.length * lines).round()
        : lines;

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
  static Stream<ValidationResult> validateFile(
    String filePath,
    TableSchema schema, {
    CsvConversionOptions options = CsvConversionOptions.defaultOptions,
    ValidationProgressCallback? onProgress,
  }) async* {
    final analysis = await analyzeFile(filePath);
    final delimiter = analysis['delimiter'] as String;
    final headers = (analysis['headers'] as List).cast<String>();

    final columnMapping = _buildColumnMapping(headers, schema);

    final parser = CsvStreamingParser(fieldDelimiter: delimiter);
    final converter = CsvDataConverter(options);

    var isFirstRow = true;
    var rowIndex = 0;

    await for (final row in parser.parseFile(filePath)) {
      if (isFirstRow) {
        isFirstRow = false;
        continue;
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

  /// Importiert eine CSV-Datei mit Upsert (UUID-basiert).
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
        message: 'CSV Import gestartet (V2 - UUID-basiert)',
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

      // UUID-Mapping für FK-Auflösung laden
      final uuidMapping = UuidMapping();
      await uuidMapping.loadFromDatabase(db);

      final parser = CsvStreamingParser(fieldDelimiter: delimiter);
      final converter = CsvDataConverter(options);

      // Bei Überschreiben: Daten löschen
      if (mode == ImportMode.overwrite) {
        await db.customStatement('DELETE FROM ${schema.sqlTableName}');
        // Mapping nach Löschen zurücksetzen
        await uuidMapping.loadFromDatabase(db);
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

            // FK-UUID-Spalten auflösen (z.B. mitglied_uuid → mitglied_id)
            if (_fkUuidMapping.containsKey(column.name)) {
              final fkTableName = _fkUuidMapping[column.name]!;
              final uuidValue =
                  converter.convert(value, ColumnDataType.text) as String?;

              if (uuidValue != null && uuidValue.isNotEmpty) {
                final localId = uuidMapping.getLocalId(fkTableName, uuidValue);
                if (localId != null) {
                  // FK-Spalte: mitglied_uuid → mitglied_id (lokale ID)
                  final fkColumnName = '${fkTableName}_id';
                  rowData[fkColumnName] = localId;
                } else {
                  throw Exception(
                    'FK-Referenz nicht gefunden: $fkTableName mit UUID "$uuidValue"',
                  );
                }
              }
              continue;
            }

            // Normale Spalten konvertieren
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
            uuidMapping,
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
          uuidMapping,
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

  /// Führt einen Batch von Upsert-Operationen aus.
  ///
  /// Verwendet `INSERT ... ON CONFLICT(uuid) DO UPDATE` für Idempotenz.
  /// Aktualisiert das UUID-Mapping nach jedem erfolgreichen Insert.
  static Future<BatchImportResult> _executeBatch(
    AppDatabase db,
    String tableName,
    List<ColumnSchema> columns,
    List<Map<String, dynamic>> rows,
    UuidMapping uuidMapping,
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

          final colSchema = columns.firstWhere(
            (c) => c.name == colName,
            orElse: () => ColumnSchema(
              name: colName,
              dataType: ColumnDataType.text,
              isNullable: true,
              isPrimaryKey: false,
            ),
          );

          try {
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

        // Upsert: INSERT ... ON CONFLICT(uuid) DO UPDATE
        final placeholders = insertColumns.map((_) => '?').join(', ');
        final updateSet = insertColumns
            .where((c) => c != 'uuid') // uuid nicht updaten
            .map((c) => '$c = EXCLUDED.$c')
            .join(', ');

        final sql = updateSet.isNotEmpty
            ? 'INSERT INTO $tableName '
                  '(${insertColumns.join(', ')}) VALUES ($placeholders) '
                  'ON CONFLICT(uuid) DO UPDATE SET $updateSet'
            : 'INSERT INTO $tableName '
                  '(${insertColumns.join(', ')}) VALUES ($placeholders)';

        await db.transaction(() async {
          await db.customStatement(sql, values);
        });

        // UUID-Mapping aktualisieren falls eine uuid vorhanden ist
        if (row.containsKey('uuid') && row['uuid'] != null) {
          final uuid = row['uuid'].toString();
          // ID des neu eingefügten/geupdateten Datensatzes abfragen
          final result = await db
              .customSelect(
                'SELECT id FROM $tableName WHERE uuid = ?',
                variables: [Variable<String>(uuid)],
              )
              .getSingleOrNull();
          if (result != null) {
            final localId = result.data['id'] as int;
            uuidMapping.addMapping(tableName, uuid, localId);
          }
        }

        successCount++;

        logger.debug(
          phase: ImportPhase.dataImport,
          message: 'Zeile erfolgreich importiert (Upsert)',
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

  /// Erstellt das Mapping: CSV-Index → ColumnSchema
  ///
  /// Unterstützt sowohl direkte Spaltennamen als auch UUID-FK-Spalten:
  /// - "mitglied_id" → mitglied_id (Integer)
  /// - "mitglied_uuid" → mitglied_uuid (wird später aufgelöst)
  static Map<int, ColumnSchema> _buildColumnMapping(
    List<String> headers,
    TableSchema schema,
  ) {
    final mapping = <int, ColumnSchema>{};
    final importable = schema.importableColumns;

    for (var i = 0; i < headers.length; i++) {
      var header = headers[i];

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

      // Prüfen ob es eine UUID-FK-Spalte ist (z.B. "mitglied_uuid")
      if (!mapping.containsKey(i)) {
        final uuidNormalized = _normalizeColumnName(header);
        for (final fkEntry in _fkUuidMapping.entries) {
          if (_normalizeColumnName(fkEntry.key) == uuidNormalized) {
            // Als Text-Spalte mit dem UUID-Namen registrieren
            mapping[i] = ColumnSchema(
              name: fkEntry.key, // z.B. "mitglied_uuid"
              dataType: ColumnDataType.text,
              isNullable: true,
              isPrimaryKey: false,
            );
            break;
          }
        }
      }
    }

    return mapping;
  }

  /// Normalisiert einen Spaltennamen für Matching.
  static String _normalizeColumnName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[€$%\(\)\[\]\{\}<>]'), '')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
  }

  /// Konvertiert einen Wert in ein SQLite-kompatibles Format.
  static dynamic _toSqlValue(dynamic value, ColumnDataType type) {
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
        return value.millisecondsSinceEpoch ~/ 1000;
    }
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

  // -------------------------------------------------------------------------
  // Bulk Import (Multi-File)
  // -------------------------------------------------------------------------

  /// Prüft, ob für einen Bulk-Import alle benötigten Tabellen (laut
  /// [_importOrder]) mit CSV-Dateien abgedeckt sind.
  ///
  /// Gibt eine Liste der fehlenden Tabellen zurück (leer = vollständig).
  static List<String> findMissingTables(
    Map<String, String> tableFiles, {
    List<String>? requiredTables,
  }) {
    final required = requiredTables ?? _importOrder;
    final missing = <String>[];
    for (final table in required) {
      if (!tableFiles.containsKey(table)) {
        missing.add(table);
      }
    }
    return missing;
  }

  /// Importiert mehrere CSV-Dateien in der korrekten Reihenfolge.
  ///
  /// [tableFiles]: Map<Tabellenname, Dateipfad>
  /// [mode]: Import-Modus (overwrite oder append)
  /// [db]: Datenbank-Instanz
  ///
  /// Bei [ImportMode.overwrite] werden alle Tabellen in umgekehrter
  /// Reihenfolge geleert, bevor der Import beginnt. Dadurch werden
  /// FK-Constraint-Probleme vermieden.
  ///
  /// Liefert ein [BulkImportResult] mit den Ergebnissen pro Tabelle.
  static Future<BulkImportResult> importMultipleFiles(
    Map<String, String> tableFiles,
    ImportMode mode,
    AppDatabase db, {
    int batchSize = 100,
    CsvConversionOptions options = CsvConversionOptions.defaultOptions,
    void Function({
      required String currentTable,
      required int tableIndex,
      required int totalTables,
      required double tableProgress,
      required int tableImportedRows,
      required int tableTotalRows,
    })?
    onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final tableResults = <BulkTableResult>[];
    var totalImported = 0;
    var totalFailed = 0;

    try {
      // -------------------------------------------------------------------
      // 1. Prüfen: Sind alle benötigten Tabellen vorhanden?
      // -------------------------------------------------------------------
      final missing = findMissingTables(tableFiles);
      if (missing.isNotEmpty) {
        return BulkImportResult(
          success: false,
          tableResults: [],
          errorMessage:
              'Es fehlen CSV-Dateien für folgende Tabellen: '
              '${missing.map((t) => _tableDisplayNames[t] ?? t).join(', ')}. '
              'Bitte stellen Sie für alle Tabellen eine CSV-Datei bereit.',
        );
      }

      // -------------------------------------------------------------------
      // 2. Bei Overwrite: Alle Tabellen in umgekehrter Reihenfolge leeren
      // -------------------------------------------------------------------
      if (mode == ImportMode.overwrite) {
        for (final table in _importOrder.reversed) {
          if (tableFiles.containsKey(table)) {
            await db.customStatement('DELETE FROM $table');
          }
        }
      }

      // -------------------------------------------------------------------
      // 3. Tabellen-Schemas laden
      // -------------------------------------------------------------------
      final allSchemas = await getImportableTables(db);
      final schemaMap = <String, TableSchema>{
        for (final s in allSchemas) s.sqlTableName: s,
      };

      // -------------------------------------------------------------------
      // 4. Tabellen in korrekter Reihenfolge importieren
      // -------------------------------------------------------------------
      for (var i = 0; i < _importOrder.length; i++) {
        final tableName = _importOrder[i];
        final filePath = tableFiles[tableName];
        if (filePath == null) continue;

        final schema = schemaMap[tableName];
        if (schema == null) {
          tableResults.add(
            BulkTableResult(
              tableName: tableName,
              displayName: _tableDisplayNames[tableName] ?? tableName,
              success: false,
              errorMessage: 'Schema für Tabelle "$tableName" nicht gefunden',
            ),
          );
          continue;
        }

        // Einzelnen Tabellen-Import durchführen
        final result = await importFile(
          filePath,
          schema,
          ImportMode.append, // Daten wurden bereits gelöscht → nur anfügen
          db,
          batchSize: batchSize,
          options: options,
          onProgress: (imported, total) {
            onProgress?.call(
              currentTable: _tableDisplayNames[tableName] ?? tableName,
              tableIndex: i,
              totalTables: _importOrder.length,
              tableProgress: total > 0 ? imported / total : 0,
              tableImportedRows: imported,
              tableTotalRows: total,
            );
          },
        );

        tableResults.add(
          BulkTableResult(
            tableName: tableName,
            displayName: _tableDisplayNames[tableName] ?? tableName,
            success: result.success,
            importedRows: result.importedRows,
            failedRows: result.failedRows,
            errorMessage: result.errorMessage,
          ),
        );

        totalImported += result.importedRows;
        totalFailed += result.failedRows;
      }

      stopwatch.stop();

      return BulkImportResult(
        success: totalFailed == 0 || totalImported > 0,
        tableResults: tableResults,
        totalImportedRows: totalImported,
        totalFailedRows: totalFailed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return BulkImportResult(
        success: false,
        tableResults: tableResults,
        totalImportedRows: totalImported,
        totalFailedRows: totalFailed,
        errorMessage: 'Bulk-Import fehlgeschlagen: $e',
      );
    }
  }
}

/// Ergebnis eines einzelnen Tabellen-Imports innerhalb eines Bulk-Imports.
class BulkTableResult {
  final String tableName;
  final String displayName;
  final bool success;
  final int importedRows;
  final int failedRows;
  final String? errorMessage;

  const BulkTableResult({
    required this.tableName,
    required this.displayName,
    required this.success,
    this.importedRows = 0,
    this.failedRows = 0,
    this.errorMessage,
  });
}

/// Ergebnis eines Bulk-Imports (mehrere Tabellen).
class BulkImportResult {
  final bool success;
  final List<BulkTableResult> tableResults;
  final int totalImportedRows;
  final int totalFailedRows;
  final String? errorMessage;

  const BulkImportResult({
    required this.success,
    required this.tableResults,
    this.totalImportedRows = 0,
    this.totalFailedRows = 0,
    this.errorMessage,
  });
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
