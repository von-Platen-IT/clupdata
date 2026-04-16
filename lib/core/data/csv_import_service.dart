import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';

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
}

/// Typfehler einer einzelnen Zelle.
class CellTypeError {
  final int row;
  final String column;
  final String value;
  final ColumnDataType expectedType;

  const CellTypeError({
    required this.row,
    required this.column,
    required this.value,
    required this.expectedType,
  });
}

/// Ergebnis der CSV-Validierung.
class CsvValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final int matchedColumnCount;
  final List<String> missingRequiredHeaders;
  final List<String> unknownHeaders;
  final int rowCount;
  final List<CellTypeError> typeErrors;

  const CsvValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.matchedColumnCount = 0,
    this.missingRequiredHeaders = const [],
    this.unknownHeaders = const [],
    this.rowCount = 0,
    this.typeErrors = const [],
  });
}

/// Ergebnis des CSV-Imports.
class CsvImportResult {
  final bool success;
  final int importedRows;
  final String? errorMessage;

  const CsvImportResult({
    required this.success,
    this.importedRows = 0,
    this.errorMessage,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Zentraler Service für CSV-Import.
///
/// Parsing, Validierung und Import als statische Methoden.
/// Kein Riverpod-Provider – DB wird als Parameter übergeben,
/// konsistent mit [DatabaseBackupService].
class CsvImportService {
  CsvImportService._();

  /// Anzeigenamen für Tabellen (SQL-Name → Deutsch).
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

  /// CSV-Codec für Deutsch/Excel: Semicolon-Trennzeichen, kein Auto-Detect.
  static final _csvCodec = Csv(fieldDelimiter: ';', autoDetect: false);

  /// Liefert alle importierbaren Tabellen mit ihren Schemas.
  ///
  /// Verwendet PRAGMA table_info für zuverlässige Schema-Introspektion.
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

  /// Validiert eine CSV-Datei gegen das Tabellen-Schema.
  ///
  /// Prüft: Header-Existenz, Pflichtspalten, Datentypen pro Zelle.
  /// Wird VOR dem eigentlichen Import aufgerufen.
  static Future<CsvValidationResult> validateCsv(
    String filePath,
    TableSchema schema,
  ) async {
    final errors = <String>[];
    final warnings = <String>[];
    final typeErrors = <CellTypeError>[];

    // 1. Datei lesen und parsen
    final rows = await _parseCsvFile(filePath);
    if (rows == null) {
      return const CsvValidationResult(
        isValid: false,
        errors: ['Datei konnte nicht gelesen werden'],
      );
    }

    if (rows.isEmpty) {
      return const CsvValidationResult(
        isValid: false,
        errors: ['Datei ist leer oder hat kein gültiges CSV-Format'],
      );
    }

    // 2. Header prüfen
    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final importable = schema.importableColumns;
    final importableNames = importable.map((c) => c.name).toSet();
    final requiredNames = schema.requiredColumns.map((c) => c.name).toSet();

    // Fehlende Pflichtspalten
    final missingRequired = requiredNames.difference(headers.toSet()).toList();
    if (missingRequired.isNotEmpty) {
      errors.add('Fehlende Pflichtspalten: ${missingRequired.join(', ')}');
    }

    // Unbekannte Spalten (id wird stillschweigend ignoriert)
    final unknownHeaders = headers
        .where((h) => !importableNames.contains(h) && h != 'id')
        .toList();
    if (unknownHeaders.isNotEmpty) {
      warnings.add(
        'Unbekannte Spalten werden ignoriert: ${unknownHeaders.join(', ')}',
      );
    }

    // Übereinstimmende Spalten zählen
    final matchedCount = headers
        .where((h) => importableNames.contains(h))
        .length;

    // 3. Datentypen prüfen (ab Zeile 2)
    final dataRows = rows.skip(1).toList();
    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      for (var j = 0; j < headers.length && j < row.length; j++) {
        final header = headers[j];
        final value = row[j].toString().trim();

        // id-Spalte und unbekannte Spalten überspringen
        if (header == 'id' || !importableNames.contains(header)) continue;

        // Leere Werte: OK bei nullable oder Spalten mit Default
        if (value.isEmpty) continue;

        // Datentyp prüfen
        final colSchema = importable.firstWhere((c) => c.name == header);
        if (!_validateType(value, colSchema.dataType)) {
          typeErrors.add(
            CellTypeError(
              row: i + 2, // +2: 1-basiert + Header-Zeile
              column: header,
              value: value,
              expectedType: colSchema.dataType,
            ),
          );
        }
      }
    }

    // Typfehler als Fehler melden (max. 10 anzeigen)
    if (typeErrors.isNotEmpty) {
      final displayErrors = typeErrors
          .take(10)
          .map(
            (e) =>
                'Zeile ${e.row}, Spalte "${e.column}": '
                '"${e.value}" ist kein gültiger ${_dataTypeLabel(e.expectedType)}',
          );
      errors.addAll(displayErrors);
      if (typeErrors.length > 10) {
        errors.add('... und ${typeErrors.length - 10} weitere Typfehler');
      }
    }

    return CsvValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      matchedColumnCount: matchedCount,
      missingRequiredHeaders: missingRequired,
      unknownHeaders: unknownHeaders,
      rowCount: dataRows.length,
      typeErrors: typeErrors,
    );
  }

  /// Führt den CSV-Import durch.
  ///
  /// [ImportMode.overwrite]: DELETE + INSERT (Transaktion)
  /// [ImportMode.append]: INSERT only (Transaktion)
  static Future<CsvImportResult> importCsv(
    String filePath,
    TableSchema schema,
    ImportMode mode,
    AppDatabase db,
  ) async {
    try {
      final rows = await _parseCsvFile(filePath);
      if (rows == null) {
        return const CsvImportResult(
          success: false,
          errorMessage: 'Datei konnte nicht gelesen werden',
        );
      }

      if (rows.length < 2) {
        return const CsvImportResult(
          success: false,
          errorMessage: 'CSV-Datei hat keine Datenzeilen',
        );
      }

      final headers = rows.first.map((h) => h.toString().trim()).toList();
      final dataRows = rows.skip(1).toList();
      final importable = schema.importableColumns;
      final importableNames = importable.map((c) => c.name).toSet();

      // Spalten-Mapping: Header-Index → ColumnSchema
      final columnMapping = <int, ColumnSchema>{};
      for (var i = 0; i < headers.length; i++) {
        if (importableNames.contains(headers[i])) {
          columnMapping[i] = importable.firstWhere((c) => c.name == headers[i]);
        }
      }

      var importedCount = 0;

      await db.transaction(() async {
        // Bei Überschreiben: vorhandene Daten löschen
        if (mode == ImportMode.overwrite) {
          await db.customStatement('DELETE FROM ${schema.sqlTableName}');
        }

        // Zeilen einfügen
        for (final row in dataRows) {
          final insertColumns = <String>[];
          final variables = <Variable>[];

          for (final entry in columnMapping.entries) {
            final colIndex = entry.key;
            final colSchema = entry.value;

            final rawValue = colIndex < row.length
                ? row[colIndex].toString().trim()
                : '';

            // Leere Werte: Spalte überspringen (Default/NULL wird verwendet)
            if (rawValue.isEmpty) continue;

            insertColumns.add(colSchema.name);
            variables.add(_toVariable(rawValue, colSchema.dataType));
          }

          if (insertColumns.isEmpty) continue;

          final placeholders = insertColumns.map((_) => '?').join(', ');
          final sql =
              'INSERT INTO ${schema.sqlTableName} '
              '(${insertColumns.join(', ')}) VALUES ($placeholders)';

          await db.customStatement(sql, variables);
          importedCount++;
        }
      });

      return CsvImportResult(success: true, importedRows: importedCount);
    } catch (e) {
      return CsvImportResult(
        success: false,
        errorMessage: 'Import fehlgeschlagen: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helpers – Schema
  // ---------------------------------------------------------------------------

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

    return rows.map((row) {
      final name = row.read<String>('name');
      final type = row.read<String>('type');
      final notNull = row.read<int>('notnull') == 1;
      final pk = row.read<int>('pk') > 0;
      final defaultValue = row.read<String?>('dflt_value');

      return ColumnSchema(
        name: name,
        dataType: _sqlTypeToDataType(type),
        isNullable: !notNull,
        isPrimaryKey: pk,
        defaultValue: defaultValue,
      );
    }).toList();
  }

  /// Wandelt SQL-Typ-String in [ColumnDataType] um.
  static ColumnDataType _sqlTypeToDataType(String sqlType) {
    final upper = sqlType.toUpperCase();
    if (upper == 'INTEGER') return ColumnDataType.integer;
    if (upper == 'REAL') return ColumnDataType.real;
    if (upper == 'TEXT') return ColumnDataType.text;
    // SQLite speichert BOOLEAN und DATETIME als INTEGER/TEXT
    // Wir behandeln sie als Text, da die Typ-Prüfung beim Import
    // die eigentliche Validierung übernimmt
    return ColumnDataType.text;
  }

  // ---------------------------------------------------------------------------
  // Private Helpers – CSV
  // ---------------------------------------------------------------------------

  /// Liest und parst eine CSV-Datei. Entfernt UTF-8 BOM falls vorhanden.
  static Future<List<List<dynamic>>?> _parseCsvFile(String filePath) async {
    try {
      var content = await File(filePath).readAsString();
      // UTF-8 BOM entfernen falls vorhanden
      if (content.startsWith('\ufeff')) {
        content = content.substring(1);
      }
      if (content.trim().isEmpty) return null;
      return _csvCodec.decoder.convert(content);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helpers – Validierung
  // ---------------------------------------------------------------------------

  /// Prüft ob ein Wert zum erwarteten Datentyp passt.
  static bool _validateType(String value, ColumnDataType type) {
    switch (type) {
      case ColumnDataType.integer:
        return int.tryParse(value) != null;
      case ColumnDataType.real:
        return _tryParseDouble(value) != null;
      case ColumnDataType.text:
        return true;
      case ColumnDataType.boolean:
        final lower = value.toLowerCase();
        return lower == '0' ||
            lower == '1' ||
            lower == 'true' ||
            lower == 'false';
      case ColumnDataType.datetime:
        return _tryParseDateTime(value) != null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helpers – Konvertierung
  // ---------------------------------------------------------------------------

  /// Erstellt eine Drift-[Variable] aus einem String-Wert.
  static Variable _toVariable(String value, ColumnDataType type) {
    switch (type) {
      case ColumnDataType.integer:
        return Variable(int.parse(value));
      case ColumnDataType.real:
        return Variable(_parseDouble(value));
      case ColumnDataType.text:
        return Variable(value);
      case ColumnDataType.boolean:
        return Variable(_parseBool(value) ? 1 : 0);
      case ColumnDataType.datetime:
        return Variable(_parseDateTime(value));
    }
  }

  /// Parst einen Double-Wert (Deutsch: 1.234,56 oder ISO: 1234.56).
  static double _parseDouble(String value) {
    return _tryParseDouble(value) ?? double.nan;
  }

  static double? _tryParseDouble(String value) {
    // ISO-Format: 1234.56
    final iso = double.tryParse(value);
    if (iso != null) return iso;

    // Deutsch-Format: 1.234,56 → 1234.56
    final cleaned = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  /// Parst einen Boolean-Wert (0/1/true/false).
  static bool _parseBool(String value) {
    final lower = value.toLowerCase();
    return lower == '1' || lower == 'true';
  }

  /// Parst einen DateTime-Wert (dd.MM.yyyy oder yyyy-MM-dd oder ISO 8601).
  static DateTime _parseDateTime(String value) {
    return _tryParseDateTime(value) ?? DateTime.now();
  }

  static DateTime? _tryParseDateTime(String value) {
    // dd.MM.yyyy
    try {
      return DateFormat('dd.MM.yyyy').parseStrict(value);
    } catch (_) {} // ignore: empty_catch

    // yyyy-MM-dd
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(value);
    } catch (_) {} // ignore: empty_catch

    // ISO 8601 (mit Zeitanteil)
    try {
      return DateTime.parse(value);
    } catch (_) {} // ignore: empty_catch

    return null;
  }

  // ---------------------------------------------------------------------------
  // Private Helpers – Anzeige
  // ---------------------------------------------------------------------------

  /// Menschenlesbarer Name für einen SQL-Tabellennamen.
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
