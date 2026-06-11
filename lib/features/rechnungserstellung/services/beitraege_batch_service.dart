import 'package:drift/drift.dart' as drift;

import '../../../core/database/database.dart';
import '../domain/models/batch_rechnung_result.dart';
import 'batch_rechnung_service.dart';

/// Configuration for the Beiträge batch operation.
class BeitraegeBatchConfig {
  final int year;
  final int month;
  final List<int> leistungIds;
  final bool nurAktiveVertraege;
  final bool nurOhneOffene;
  final String initialStatus;
  final String? bemerkung;
  final bool quartalsweise;

  const BeitraegeBatchConfig({
    required this.year,
    required this.month,
    this.leistungIds = const [],
    this.nurAktiveVertraege = true,
    this.nurOhneOffene = false,
    this.initialStatus = 'kontiert',
    this.bemerkung,
    this.quartalsweise = false,
  });
}

/// Service for batch-generating contribution invoices (Beiträge).
///
/// Extends [BatchRechnungService] for shared member loading and result
/// building. Creates `beitrag` records with `beitrag_status_verlauf` entries.
///
/// Invoice number format: `RE-YYYY-XXXXX`
class BeitraegeBatchService extends BatchRechnungService {
  BeitraegeBatchService(super.db);

  /// Generates Beiträge for the given [config].
  ///
  /// For each qualifying member:
  /// 1. Creates a price snapshot (mitglied.preis or leistung.preis)
  /// 2. Inserts a `beitrag` record with the configured status
  /// 3. Records the initial status in `beitrag_status_verlauf`
  ///
  /// Members are skipped if a Beitrag already exists for the same period.
  Future<BatchRechnungResult> run(BeitraegeBatchConfig config) async {
    return execute(config: config);
  }

  @override
  Future<BatchRechnungResult> execute({
    void Function(int processed, int total)? onProgress,
    BeitraegeBatchConfig? config,
  }) async {
    if (config == null) {
      throw ArgumentError('BeitraegeBatchConfig is required');
    }

    final errors = <String>[];
    final erstellt = <BatchRechnungEintrag>[];
    var successCount = 0;
    var skippedCount = 0;

    // Determine which months to process
    final months = <DateTime>[];
    if (config.quartalsweise) {
      for (var i = 0; i < 3; i++) {
        final m = config.month + i;
        final adjustedYear = config.year + ((m - 1) ~/ 12);
        final adjustedMonth = ((m - 1) % 12) + 1;
        months.add(DateTime(adjustedYear, adjustedMonth, 1));
      }
    } else {
      months.add(DateTime(config.year, config.month, 1));
    }

    // Load members with contracts
    var members = await loadMembersWithContracts(
      leistungIds: config.leistungIds.isNotEmpty ? config.leistungIds : null,
      nurAktiveVertraege: config.nurAktiveVertraege,
    );

    // Enrich with prices
    members = await enrichWithPrices(members);

    // Process each month
    for (final abrechnungsZeitraum in months) {
      final year = abrechnungsZeitraum.year;
      final month = abrechnungsZeitraum.month;

      // Get existing Beiträge for this period
      final existingKeys = await _getExistingBeitragKeys(year, month);

      // Filter members to process
      var toProcess = members.where((m) {
        final key = '${m.mitgliedId}_$year-$month';
        return !existingKeys.contains(key);
      }).toList();

      // If nurOhneOffene: also exclude members with open/contested beiträge
      if (config.nurOhneOffene) {
        final membersWithOffene = await _getMembersWithOffeneBeitraege();
        toProcess = toProcess
            .where((m) => !membersWithOffene.contains(m.mitgliedId))
            .toList();
      }

      final totalSkipped = members.length - toProcess.length;
      skippedCount += totalSkipped;

      final kontierungDate = DateTime.now();

      // Process each member
      for (var i = 0; i < toProcess.length; i++) {
        final memberData = toProcess[i];

        try {
          final rechnungsnummer = await rechnungsnummerGenerator
              .generateForBeitrag();

          // Create price snapshot
          final preisId = await db
              .into(db.preis)
              .insert(
                PreisCompanion.insert(
                  bruttopreis: memberData.effectiveBruttopreis,
                ),
              );

          // Insert the Beitrag
          final beitragId = await db
              .into(db.beitraege)
              .insert(
                BeitraegeCompanion.insert(
                  mitgliedId: memberData.mitgliedId,
                  leistungId: memberData.leistungId,
                  preisId: drift.Value(preisId),
                  rechnungsnummer: rechnungsnummer,
                  status: config.initialStatus,
                  kontiertAm: kontierungDate,
                  abrechnungsZeitraum: drift.Value(abrechnungsZeitraum),
                  statusDatum: kontierungDate,
                ),
              );

          // Record initial status in history
          await db
              .into(db.beitragStatusVerlauf)
              .insert(
                BeitragStatusVerlaufCompanion.insert(
                  beitragId: beitragId,
                  status: config.initialStatus,
                  geaendertAm: DateTime.now(),
                  bemerkung: config.bemerkung?.isNotEmpty == true
                      ? config.bemerkung!
                      : 'Beitrag durch Rechnungslegung erstellt',
                ),
              );

          erstellt.add(
            BatchRechnungEintrag(
              rechnungsnummer: rechnungsnummer,
              kundeName: memberData.fullName,
              betragBrutto: memberData.effectiveBruttopreis,
            ),
          );
          successCount++;
        } catch (e) {
          errors.add('${memberData.fullName}: $e');
        }

        onProgress?.call(i + 1, toProcess.length);
      }
    }

    return buildResult(
      successCount: successCount,
      skippedCount: skippedCount,
      errors: errors,
      erstellteRechnungen: erstellt,
    );
  }

  /// Gets keys of existing Beiträge for a given period.
  /// Key format: "mitgliedId_year-month"
  Future<Set<String>> _getExistingBeitragKeys(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    final existing =
        await (db.select(db.beitraege)..where(
              (b) =>
                  b.abrechnungsZeitraum.isBiggerOrEqualValue(startDate) &
                  b.abrechnungsZeitraum.isSmallerThanValue(endDate),
            ))
            .get();

    return existing.map((b) {
      final abrMonth = b.abrechnungsZeitraum!.month;
      final abrYear = b.abrechnungsZeitraum!.year;
      return '${b.mitgliedId}_$abrYear-$abrMonth';
    }).toSet();
  }

  /// Gets IDs of members that have open or contested Beiträge.
  Future<Set<int>> _getMembersWithOffeneBeitraege() async {
    final existing =
        await (db.select(db.beitraege)..where(
              (b) => b.status.equals('kontiert') | b.status.equals('offen'),
            ))
            .get();

    return existing.map((b) => b.mitgliedId).toSet();
  }
}
