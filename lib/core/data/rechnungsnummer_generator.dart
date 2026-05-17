import 'package:drift/drift.dart';

import '../database/database.dart';

/// Shared service for generating unique invoice numbers.
///
/// Both [BeitraegeRepository] and [RechnungenRepository] delegate
/// rechnungsnummer generation to this class to eliminate duplicated logic.
///
/// Format differs by entity:
/// - Beiträge: `RE-YYYY-XXXXX` (prefix "RE-")
/// - Rechnungen: `R-YYYY-XXXXX` (prefix "R-")
class RechnungsnummerGenerator {
  final AppDatabase _db;

  RechnungsnummerGenerator(this._db);

  /// Generates a unique invoice number for Beiträge.
  /// Format: `RE-YYYY-XXXXX` where XXXXX is a sequential 5-digit number.
  Future<String> generateForBeitrag() => _generate(
    prefix: 'RE',
    tableName: 'beitrag',
    prefixLength: 3, // "RE-" in substr is 1-indexed, so start = prefixLen + 1
    existsFn: _beitragRechnungsnummerExists,
  );

  /// Generates a unique invoice number for Rechnungen.
  /// Format: `R-YYYY-XXXXX` where XXXXX is a sequential 5-digit number.
  Future<String> generateForRechnung() => _generate(
    prefix: 'R',
    tableName: 'rechnung',
    prefixLength: 2, // "R-" in substr is 1-indexed, so start = prefixLen + 1
    existsFn: _rechnungRechnungsnummerExists,
  );

  // ── Shared generation logic ──────────────────────────────────────────────

  /// Core number generation shared by both entity types.
  ///
  /// The [tableName] and [prefix] are hardcoded by the two public methods,
  /// never derived from user input – therefore safe from SQL injection.
  Future<String> _generate({
    required String prefix,
    required String tableName,
    required int prefixLength,
    required Future<bool> Function(String) existsFn,
  }) async {
    final now = DateTime.now();
    final year = now.year;
    final substrStart = prefixLength + 1; // 1-indexed for SQLite

    // Get the highest existing number for this year
    final result = await _db
        .customSelect(
          // tableName is hardcoded in calling methods → safe
          'SELECT MAX(CAST(substr(rechnungsnummer, $substrStart, 4) AS INTEGER)) '
          'as max_num FROM $tableName '
          'WHERE substr(rechnungsnummer, $substrStart, 4) = ?',
          variables: [Variable<String>(year.toString())],
        )
        .getSingle();

    final maxNumber = (result.data['max_num'] as int?) ?? 0;
    int nextNumber = maxNumber + 1;

    // Ensure uniqueness (in case of gaps or manual insertions)
    String candidate = '$prefix$year-${nextNumber.toString().padLeft(5, '0')}';
    while (await existsFn(candidate)) {
      nextNumber++;
      candidate = '$prefix$year-${nextNumber.toString().padLeft(5, '0')}';
    }

    return candidate;
  }

  /// Checks if a rechnungsnummer already exists in the `beitrag` table.
  Future<bool> _beitragRechnungsnummerExists(String rechnungsnummer) async {
    final result = await (_db.select(
      _db.beitraege,
    )..where((b) => b.rechnungsnummer.equals(rechnungsnummer))).get();
    return result.isNotEmpty;
  }

  /// Checks if a rechnungsnummer already exists in the `rechnung` table.
  Future<bool> _rechnungRechnungsnummerExists(String rechnungsnummer) async {
    final result = await (_db.select(
      _db.rechnungen,
    )..where((r) => r.rechnungsnummer.equals(rechnungsnummer))).get();
    return result.isNotEmpty;
  }
}
