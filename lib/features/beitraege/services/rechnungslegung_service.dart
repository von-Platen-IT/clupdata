import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show innerJoin, leftOuterJoin;

import '../../../core/database/database.dart';

/// Result of a batch billing operation.
class RechnungslegungResult {
  final int successCount;
  final int skippedCount;
  final List<String> errors;

  const RechnungslegungResult({
    required this.successCount,
    required this.skippedCount,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get total => successCount + skippedCount;
}

/// Service for generating contribution invoices for all members.
///
/// This service creates Beitrag entries for all members that have:
/// - A valid contract (leistungId is set)
/// - Not already been billed for the specified period
///
/// The service uses batch operations for optimal performance.
class RechnungslegungService {
  final AppDatabase _db;

  const RechnungslegungService(this._db);

  /// Generates contribution entries (Beitraege) for all members for a given year and month.
  ///
  /// For each member with a valid contract:
  /// - Creates a Beitrag entry with status 'kontiert'
  /// - Uses the member's assigned price (preisId) or falls back to the Leistung price
  /// - Generates a unique invoice number
  /// - Sets kontiertAm to the first day of the specified month
  /// - Records the initial status in BeitragStatusVerlauf
  ///
  /// Members are skipped if:
  /// - They have no leistungId assigned
  /// - A Beitrag already exists for this member in the specified month/year
  Future<RechnungslegungResult> generateBeitraegeForPeriod({
    required int year,
    required int month,
    void Function(int processed, int total)? onProgress,
  }) async {
    final errors = <String>[];
    var successCount = 0;
    var skippedCount = 0;

    // Das Kontierungsdatum ist immer das aktuelle Datum (wann der Automatismus gestartet wurde)
    final kontierungDate = DateTime.now();
    // Der Abrechnungszeitraum ist der 1. des gewählten Monats
    final abrechnungsZeitraum = DateTime(year, month, 1);

    // Get all members with their contracts and prices in a single query
    final membersWithContracts = await _getMembersWithContracts();

    // Filter out members that already have a Beitrag for this period
    final existingBeitragKeys = await _getExistingBeitragKeys(year, month);

    final membersToProcess = membersWithContracts.where((m) {
      final key = '${m.mitglied.id}_$year-$month';
      return !existingBeitragKeys.contains(key);
    }).toList();

    final totalMembers = membersToProcess.length;

    // Process each member
    for (var i = 0; i < membersToProcess.length; i++) {
      final memberData = membersToProcess[i];

      try {
        await _createBeitragForMember(
          memberData: memberData,
          kontierungDate: kontierungDate,
          abrechnungsZeitraum: abrechnungsZeitraum,
        );
        successCount++;
      } catch (e) {
        errors.add(
          '${memberData.mitglied.name}, ${memberData.mitglied.vorname}: $e',
        );
      }

      // Report progress
      onProgress?.call(i + 1, totalMembers);
    }

    // Count skipped members
    skippedCount = membersWithContracts.length - membersToProcess.length;

    return RechnungslegungResult(
      successCount: successCount,
      skippedCount: skippedCount,
      errors: errors,
    );
  }

  /// Gets all members that have a valid contract (leistungId is set).
  /// Includes the member, their leistung, and their price information.
  Future<List<_MemberContractData>> _getMembersWithContracts() async {
    final query = _db.select(_db.mitglieds).join([
      innerJoin(
        _db.leistung,
        _db.leistung.id.equalsExp(_db.mitglieds.leistungId),
      ),
      leftOuterJoin(_db.preis, _db.preis.id.equalsExp(_db.mitglieds.preisId)),
    ]);

    final results = await query.get();

    return results.map((row) {
      return _MemberContractData(
        mitglied: row.readTable(_db.mitglieds),
        leistung: row.readTable(_db.leistung),
        memberPrice: row.readTableOrNull(_db.preis),
      );
    }).toList();
  }

  /// Gets a set of keys for existing Beitraege in the specified period.
  /// Key format: "mitgliedId_year-month"
  Future<Set<String>> _getExistingBeitragKeys(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    final existingBeitraege =
        await (_db.select(_db.beitraege)..where(
              (b) =>
                  b.abrechnungsZeitraum.isBiggerOrEqualValue(startDate) &
                  b.abrechnungsZeitraum.isSmallerThanValue(endDate),
            ))
            .get();

    return existingBeitraege.map((b) {
      final abrMonth = b.abrechnungsZeitraum!.month;
      final abrYear = b.abrechnungsZeitraum!.year;
      return '${b.mitgliedId}_$abrYear-$abrMonth';
    }).toSet();
  }

  /// Creates a Beitrag entry for a single member.
  Future<void> _createBeitragForMember({
    required _MemberContractData memberData,
    required DateTime kontierungDate,
    required DateTime abrechnungsZeitraum,
  }) async {
    final mitglied = memberData.mitglied;
    final leistung = memberData.leistung;

    // Determine the price to use:
    // 1. Member's specific price if available
    // 2. Otherwise, the Leistung's price
    int? preisId = mitglied.preisId;

    if (preisId == null) {
      // Load the leistung's price
      final leistungPreis = await (_db.select(
        _db.preis,
      )..where((p) => p.id.equals(leistung.preisId))).getSingleOrNull();

      if (leistungPreis == null) {
        throw Exception('Kein Preis für Vertragsart ${leistung.name} gefunden');
      }

      // Create a snapshot of the leistung price
      preisId = await _db
          .into(_db.preis)
          .insert(
            PreisCompanion.insert(bruttopreis: leistungPreis.bruttopreis),
          );
    } else {
      // Create a snapshot of the member's price
      final memberPreis = memberData.memberPrice;
      if (memberPreis == null) {
        throw Exception('Preis nicht gefunden');
      }

      preisId = await _db
          .into(_db.preis)
          .insert(PreisCompanion.insert(bruttopreis: memberPreis.bruttopreis));
    }

    // Generate invoice number
    final rechnungsnummer = await _generateRechnungsnummer();

    // Insert the Beitrag
    final beitragId = await _db
        .into(_db.beitraege)
        .insert(
          BeitraegeCompanion.insert(
            mitgliedId: mitglied.id,
            leistungId: leistung.id,
            preisId: drift.Value(preisId),
            rechnungsnummer: rechnungsnummer,
            status: 'kontiert',
            kontiertAm: kontierungDate,
            abrechnungsZeitraum: drift.Value(abrechnungsZeitraum),
            statusDatum: kontierungDate,
          ),
        );

    // Record initial status in history
    await _db
        .into(_db.beitragStatusVerlauf)
        .insert(
          BeitragStatusVerlaufCompanion.insert(
            beitragId: beitragId,
            status: 'kontiert',
            geaendertAm: DateTime.now(),
            bemerkung: 'Beitrag durch Rechnungslegung erstellt',
          ),
        );
  }

  /// Generates a unique invoice number in the format RE-YYYY-XXXX
  Future<String> _generateRechnungsnummer() async {
    final year = DateTime.now().year;
    final prefix = 'RE-$year-';

    // Get the highest existing invoice number for this year
    final existingNumbers =
        await (_db.select(_db.beitraege)
              ..where((b) => b.rechnungsnummer.like('$prefix%'))
              ..orderBy([(b) => drift.OrderingTerm.desc(b.rechnungsnummer)])
              ..limit(1))
            .get();

    int nextNumber = 1;
    if (existingNumbers.isNotEmpty) {
      final lastNumber = existingNumbers.first.rechnungsnummer;
      final numberPart = lastNumber.substring(prefix.length);
      nextNumber = int.tryParse(numberPart) ?? 0;
      nextNumber++;
    }

    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }
}

/// Internal data class holding member contract information.
class _MemberContractData {
  final Mitglied mitglied;
  final LeistungItem leistung;
  final PreisItem? memberPrice;

  const _MemberContractData({
    required this.mitglied,
    required this.leistung,
    this.memberPrice,
  });
}
