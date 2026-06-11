import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show innerJoin, leftOuterJoin;

import '../../../core/database/database.dart';
import '../../../core/data/rechnungsnummer_generator.dart';
import '../domain/models/batch_rechnung_result.dart';

/// Abstract base class for batch invoice generation.
///
/// Both [BeitraegeBatchService] and [VerkaufBatchService] extend this class
/// to share common logic: member loading, progress tracking, error collection,
/// and invoice number generation.
///
/// Subclasses implement [execute] with their specific business rules.
abstract class BatchRechnungService {
  final AppDatabase db;
  late final RechnungsnummerGenerator rechnungsnummerGenerator;

  BatchRechnungService(this.db) {
    rechnungsnummerGenerator = RechnungsnummerGenerator(db);
  }

  /// Executes the batch operation.
  ///
  /// Implementations should:
  /// 1. Load relevant data
  /// 2. Filter/deduplicate
  /// 3. Process each entry with progress reporting
  /// 4. Return a [BatchRechnungResult] with details
  Future<BatchRechnungResult> execute({
    void Function(int processed, int total)? onProgress,
  });

  // ── Shared member loading ──────────────────────────────────────────────

  /// Loads all members with valid contracts (leistungId is set).
  /// Returns enriched [MemberContractData] with price information.
  ///
  /// [leistungIds] — optional filter: only members with these Leistungen.
  /// [nurAktiveVertraege] — if true, only members with vertrag_laufzeit_bis >= today.
  Future<List<MemberContractData>> loadMembersWithContracts({
    List<int>? leistungIds,
    bool nurAktiveVertraege = false,
  }) async {
    final query = db.select(db.mitglieds).join([
      innerJoin(db.leistung, db.leistung.id.equalsExp(db.mitglieds.leistungId)),
      leftOuterJoin(db.preis, db.preis.id.equalsExp(db.mitglieds.preisId)),
    ]);

    // Filter by Leistungen if specified
    if (leistungIds != null && leistungIds.isNotEmpty) {
      query.where(db.leistung.id.isIn(leistungIds));
    }

    // Filter by active contracts
    if (nurAktiveVertraege) {
      query.where(
        db.mitglieds.vertragLaufzeitBis.isBiggerOrEqualValue(DateTime.now()),
      );
    }

    final results = await query.get();

    return results.map((row) {
      final mitglied = row.readTable(db.mitglieds);
      final leistung = row.readTable(db.leistung);
      final memberPrice = row.readTableOrNull(db.preis);

      return MemberContractData(
        mitgliedId: mitglied.id,
        name: mitglied.name,
        vorname: mitglied.vorname,
        leistungId: leistung.id,
        leistungName: leistung.name,
        bruttopreis: 0, // will be set from leistung price below
        mitgliedPreisId: memberPrice?.id,
        mitgliedBruttopreis: memberPrice?.bruttopreis,
      );
    }).toList();
  }

  /// Loads the bruttopreis for a given Leistung.
  Future<double> loadLeistungBruttopreis(int leistungId) async {
    final query = db.select(db.leistung).join([
      innerJoin(db.preis, db.preis.id.equalsExp(db.leistung.preisId)),
    ])..where(db.leistung.id.equals(leistungId));

    final row = await query.getSingleOrNull();
    if (row == null) return 0;
    return row.readTable(db.preis).bruttopreis;
  }

  /// Enriches [MemberContractData] with the correct Leistung price.
  ///
  /// Members with a member-specific price keep that price.
  /// Others get the Leistung's default price.
  Future<List<MemberContractData>> enrichWithPrices(
    List<MemberContractData> members,
  ) async {
    // Cache leistung prices
    final leistungPrices = <int, double>{};

    final enriched = <MemberContractData>[];
    for (final m in members) {
      if (!leistungPrices.containsKey(m.leistungId)) {
        leistungPrices[m.leistungId] = await loadLeistungBruttopreis(
          m.leistungId,
        );
      }

      final leistungPreis = leistungPrices[m.leistungId] ?? 0;

      enriched.add(
        MemberContractData(
          mitgliedId: m.mitgliedId,
          name: m.name,
          vorname: m.vorname,
          leistungId: m.leistungId,
          leistungName: m.leistungName,
          bruttopreis: leistungPreis,
          mitgliedPreisId: m.mitgliedPreisId,
          mitgliedBruttopreis: m.mitgliedBruttopreis,
        ),
      );
    }

    return enriched;
  }

  // ── Shared result building ─────────────────────────────────────────────

  /// Creates a [BatchRechnungResult] from collected data.
  BatchRechnungResult buildResult({
    required int successCount,
    required int skippedCount,
    required List<String> errors,
    List<BatchRechnungEintrag> erstellteRechnungen = const [],
  }) {
    return BatchRechnungResult(
      successCount: successCount,
      skippedCount: skippedCount,
      errors: errors,
      erstellteRechnungen: erstellteRechnungen,
    );
  }
}
