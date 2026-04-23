import 'package:flutter/foundation.dart';

/// Log-Level für Import-Operationen.
enum ImportLogLevel {
  debug, // Detaillierte Ablaufinformationen
  info, // Normale Fortschritte
  warning, // Probleme die behoben wurden
  error, // Fehler die den Import beeinträchtigen
  critical, // Fehler die den Import abbrechen
}

/// Phasen des Import-Prozesses.
enum ImportPhase {
  initialization,
  fileAnalysis,
  schemaMapping,
  dataValidation,
  dataImport,
  completion,
}

/// Ein einzelner Log-Eintrag.
class ImportLogEntry {
  final DateTime timestamp;
  final ImportLogLevel level;
  final ImportPhase phase;
  final String message;
  final Map<String, dynamic>? context;
  final Object? error;
  final StackTrace? stackTrace;

  const ImportLogEntry({
    required this.timestamp,
    required this.level,
    required this.phase,
    required this.message,
    this.context,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('${level.name.toUpperCase().padRight(8)} ');
    buffer.write('[${phase.name.padRight(15)}] ');
    buffer.write(message);
    return buffer.toString();
  }
}

/// Zusammenfassung der Import-Logs.
class ImportLogSummary {
  final int totalLogs;
  final int errors;
  final int warnings;
  final ImportLogEntry? firstError;
  final ImportLogEntry? criticalError;

  const ImportLogSummary({
    required this.totalLogs,
    required this.errors,
    required this.warnings,
    this.firstError,
    this.criticalError,
  });

  bool get hasErrors => errors > 0;
  bool get hasCriticalError => criticalError != null;
}

/// Logger für CSV-Import-Operationen mit strukturiertem Logging.
///
/// Bietet:
/// - Verschiedene Log-Level (debug, info, warning, error, critical)
/// - Kontextuelle Informationen (Phase, Zeile, Spalte, Wert)
/// - Export der Logs als lesbare Datei
/// - Zusammenfassungen für UI-Anzeige
class ImportLogger {
  final List<ImportLogEntry> _logs = [];
  final void Function(ImportLogEntry)? onLog;

  ImportLogger({this.onLog});

  /// Gibt alle Log-Einträge zurück.
  List<ImportLogEntry> get logs => List.unmodifiable(_logs);

  /// Loggt eine Debug-Nachricht.
  void debug({
    required ImportPhase phase,
    required String message,
    Map<String, dynamic>? context,
  }) => _log(ImportLogLevel.debug, phase, message, context);

  /// Loggt eine Info-Nachricht.
  void info({
    required ImportPhase phase,
    required String message,
    Map<String, dynamic>? context,
  }) => _log(ImportLogLevel.info, phase, message, context);

  /// Loggt eine Warnung.
  void warning({
    required ImportPhase phase,
    required String message,
    Map<String, dynamic>? context,
    Object? error,
  }) => _log(ImportLogLevel.warning, phase, message, context, error: error);

  /// Loggt einen Fehler.
  void error({
    required ImportPhase phase,
    required String message,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(
    ImportLogLevel.error,
    phase,
    message,
    context,
    error: error,
    stackTrace: stackTrace,
  );

  /// Loggt einen kritischen Fehler.
  void critical({
    required ImportPhase phase,
    required String message,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(
    ImportLogLevel.critical,
    phase,
    message,
    context,
    error: error,
    stackTrace: stackTrace,
  );

  void _log(
    ImportLogLevel level,
    ImportPhase phase,
    String message,
    Map<String, dynamic>? context, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = ImportLogEntry(
      timestamp: DateTime.now(),
      level: level,
      phase: phase,
      message: message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);
    onLog?.call(entry);

    // Auch in debugPrint für Development
    _printLog(entry);
  }

  void _printLog(ImportLogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String();
    final level = entry.level.name.toUpperCase().padRight(8);
    final phase = entry.phase.name.padRight(15);

    debugPrint('[$timestamp] $level [$phase] ${entry.message}');

    if (entry.context != null && entry.context!.isNotEmpty) {
      debugPrint('  Context: ${entry.context}');
    }

    if (entry.error != null) {
      debugPrint('  Error: ${entry.error}');
    }

    if (entry.stackTrace != null && entry.level == ImportLogLevel.critical) {
      debugPrint('  Stack: ${entry.stackTrace}');
    }
  }

  /// Exportiert alle Logs als lesbare Text-Datei.
  String exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=' * 80);
    buffer.writeln('CSV IMPORT LOG');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    for (final entry in _logs) {
      buffer.writeln(
        '[${entry.timestamp.toIso8601String()}] ${entry.level.name.toUpperCase()}',
      );
      buffer.writeln('Phase: ${entry.phase.name}');
      buffer.writeln('Message: ${entry.message}');

      if (entry.context != null && entry.context!.isNotEmpty) {
        buffer.writeln('Context:');
        entry.context!.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
      }

      if (entry.error != null) {
        buffer.writeln('Error: ${entry.error}');
      }

      if (entry.stackTrace != null) {
        buffer.writeln('Stack Trace:');
        buffer.writeln(entry.stackTrace.toString());
      }

      buffer.writeln('-' * 80);
    }

    return buffer.toString();
  }

  /// Erstellt eine Zusammenfassung der Logs für UI-Anzeige.
  ImportLogSummary getSummary() {
    var errorCount = 0;
    var warningCount = 0;
    ImportLogEntry? firstError;
    ImportLogEntry? criticalError;

    for (final log in _logs) {
      if (log.level == ImportLogLevel.error ||
          log.level == ImportLogLevel.critical) {
        errorCount++;
        firstError ??= log;
        if (log.level == ImportLogLevel.critical) {
          criticalError ??= log;
        }
      } else if (log.level == ImportLogLevel.warning) {
        warningCount++;
      }
    }

    return ImportLogSummary(
      totalLogs: _logs.length,
      errors: errorCount,
      warnings: warningCount,
      firstError: firstError,
      criticalError: criticalError,
    );
  }

  /// Gibt alle Fehlermeldungen zurück (für UI-Anzeige).
  List<String> getErrorMessages({int? limit}) {
    final errorLogs = _logs.where(
      (log) =>
          log.level == ImportLogLevel.error ||
          log.level == ImportLogLevel.critical,
    );

    final messages = errorLogs.map((log) {
      final contextStr =
          log.context != null && log.context!.containsKey('rowIndex')
          ? ' (Zeile ${log.context!['rowIndex']})'
          : '';
      return '${log.message}$contextStr';
    }).toList();

    if (limit != null && messages.length > limit) {
      return messages.take(limit).toList()
        ..add('... und ${messages.length - limit} weitere Fehler');
    }

    return messages;
  }

  /// Löscht alle Log-Einträge.
  void clear() {
    _logs.clear();
  }
}

/// Hilfsklasse für String-Wiederholungen.
extension _StringRepeat on String {
  String operator *(int count) => List.filled(count, this).join();
}
