import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/core/data/bemerkung_repository.dart';
import 'package:clupdata/core/providers/database_provider.dart';
import 'package:clupdata/features/beitraege/domain/models/beitrag_row_data.dart';

part 'beitraege_repository.g.dart';

/// Repository for all database operations on the [Beitraege] table.
class BeitraegeRepository {
  final AppDatabase _db;
  final BemerkungRepository _bemerkungRepo;
  BeitraegeRepository(this._db, this._bemerkungRepo);

  // ── Bemerkung ─────────────────────────────────────────────────────────────

  /// Saves a Bemerkung (insert or update) and returns the ID.
  /// Delegates to the central [BemerkungRepository].
  Future<int> saveBemerkung(int? existingId, String titel, String text) {
    return _bemerkungRepo.saveBemerkung(existingId, titel, text);
  }

  /// Saves a Bemerkung only if title or text is non-empty.
  /// Delegates to the central [BemerkungRepository].
  Future<int?> saveBemerkungIfContent(
    int? existingId,
    String titel,
    String text,
  ) {
    return _bemerkungRepo.saveBemerkungIfContent(existingId, titel, text);
  }

  /// Gets a Bemerkung by its ID.
  /// Delegates to the central [BemerkungRepository].
  Future<BemerkungData?> getBemerkungById(int id) {
    return _bemerkungRepo.getBemerkungById(id);
  }

  /// Streams the [BemerkungData] linked to a [Beitrag] by [beitragId].
  Stream<BemerkungData?> watchBemerkungForBeitrag(int beitragId) {
    final query = _db.select(_db.beitraege).join([
      leftOuterJoin(
        _db.bemerkung,
        _db.bemerkung.id.equalsExp(_db.beitraege.bemerkungId),
      ),
    ])..where(_db.beitraege.id.equals(beitragId));
    return query.watchSingleOrNull().map(
      (row) => row?.readTableOrNull(_db.bemerkung),
    );
  }

  // ── Beiträge list ─────────────────────────────────────────────────────────

  /// Streams the full list of [BeitragRowData], joined with Mitglied and Leistung.
  Stream<List<BeitragRowData>> watchBeitraege() {
    final query = _db.select(_db.beitraege).join([
      innerJoin(
        _db.mitglieds,
        _db.mitglieds.id.equalsExp(_db.beitraege.mitgliedId),
      ),
      innerJoin(
        _db.leistung,
        _db.leistung.id.equalsExp(_db.beitraege.leistungId),
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final beitrag = row.readTable(_db.beitraege);
        final mitglied = row.readTable(_db.mitglieds);
        final leistung = row.readTable(_db.leistung);
        return BeitragRowData(
          beitrag: beitrag,
          mitgliedName: '${mitglied.name}, ${mitglied.vorname}',
          leistungName: leistung.name,
        );
      }).toList();
    });
  }

  /// Fetches a single [Beitrag] by its [id].
  Future<Beitrag?> getBeitragById(int id) {
    return (_db.select(
      _db.beitraege,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Streams a single [BeitragRowData] by ID with joined Mitglied and Leistung.
  /// More efficient than watching the entire list when only one item is needed.
  Stream<BeitragRowData?> watchSingleBeitrag(int beitragId) {
    final query = _db.select(_db.beitraege).join([
      innerJoin(
        _db.mitglieds,
        _db.mitglieds.id.equalsExp(_db.beitraege.mitgliedId),
      ),
      innerJoin(
        _db.leistung,
        _db.leistung.id.equalsExp(_db.beitraege.leistungId),
      ),
    ])..where(_db.beitraege.id.equals(beitragId));

    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      final beitrag = row.readTable(_db.beitraege);
      final mitglied = row.readTable(_db.mitglieds);
      final leistung = row.readTable(_db.leistung);
      return BeitragRowData(
        beitrag: beitrag,
        mitgliedName: '${mitglied.name}, ${mitglied.vorname}',
        leistungName: leistung.name,
      );
    });
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new Beitrag and immediately records the initial status
  /// in [BeitragStatusVerlauf].
  Future<int> addBeitrag(BeitraegeCompanion beitrag) async {
    final id = await _db.into(_db.beitraege).insert(beitrag);
    await _addStatusEintrag(
      beitragId: id,
      status: beitrag.status.value,
      bemerkung: 'Beitrag angelegt',
    );
    return id;
  }

  /// Updates an existing [Beitrag].
  /// If the [status] changed compared to the current DB value, a new
  /// [BeitragStatusVerlauf] entry is automatically inserted.
  /// [statusBemerkung] is REQUIRED when status changes (defaults to 'Status geändert').
  Future<void> updateBeitrag(
    BeitraegeCompanion beitrag, {
    String? statusBemerkung,
  }) async {
    // Determine whether status actually changed
    final current = await getBeitragById(beitrag.id.value);
    final statusChanged =
        current != null &&
        beitrag.status.present &&
        beitrag.status.value.toLowerCase() != current.status.toLowerCase();

    await (_db.update(
      _db.beitraege,
    )..where((b) => b.id.equals(beitrag.id.value))).write(beitrag);

    if (statusChanged) {
      await _addStatusEintrag(
        beitragId: beitrag.id.value,
        status: beitrag.status.value,
        bemerkung: statusBemerkung ?? 'Status geändert',
      );
    } else if (statusBemerkung != null && statusBemerkung.isNotEmpty) {
      // If a status remark was provided but status didn't change (edge case),
      // still add a history entry to document the action
      await _addStatusEintrag(
        beitragId: beitrag.id.value,
        status: beitrag.status.present ? beitrag.status.value : current!.status,
        bemerkung: statusBemerkung,
      );
    }
  }

  /// Deletes a [Beitrag] and all its [BeitragStatusVerlauf] entries (via CASCADE).
  Future<int> deleteBeitrag(int id) {
    return (_db.delete(_db.beitraege)..where((b) => b.id.equals(id))).go();
  }

  // ── Status-Verlauf ────────────────────────────────────────────────────────

  /// Inserts an immutable status history entry. Should only be called by
  /// [addBeitrag] and [updateBeitrag] — never directly from UI code.
  /// [bemerkung] is REQUIRED and must not be empty.
  Future<void> _addStatusEintrag({
    required int beitragId,
    required String status,
    required String bemerkung,
  }) {
    return _db
        .into(_db.beitragStatusVerlauf)
        .insert(
          BeitragStatusVerlaufCompanion.insert(
            beitragId: beitragId,
            status: status,
            geaendertAm: DateTime.now(),
            bemerkung: bemerkung,
          ),
        );
  }

  /// Streams all [BeitragStatusVerlaufData] entries for a given [beitragId],
  /// ordered by [geaendertAm] descending (newest first).
  Stream<List<BeitragStatusVerlaufData>> watchStatusVerlauf(int beitragId) {
    return (_db.select(_db.beitragStatusVerlauf)
          ..where((v) => v.beitragId.equals(beitragId))
          ..orderBy([(v) => OrderingTerm.desc(v.geaendertAm)]))
        .watch();
  }

  // ── Invoice Number Generation ─────────────────────────────────────────────

  /// Generates a unique invoice number with encoded date.
  /// Format: RE-YYYY-XXXXX where XXXXX is a sequential number.
  /// Ensures the generated number is unique by checking against existing entries.
  Future<String> generateRechnungsnummer() async {
    final now = DateTime.now();
    final year = now.year;

    // Get the highest existing number for this year
    final result = await _db
        .customSelect(
          "SELECT MAX(CAST(substr(rechnungsnummer, 9) AS INTEGER)) as max_num "
          "FROM beitrag WHERE substr(rechnungsnummer, 4, 4) = ?",
          variables: [Variable<String>(year.toString())],
        )
        .getSingle();

    final maxNumber = (result.data['max_num'] as int?) ?? 0;
    int nextNumber = maxNumber + 1;

    // Ensure uniqueness (in case of gaps or manual insertions)
    String candidate = 'RE-$year-${nextNumber.toString().padLeft(5, '0')}';
    while (await rechnungsnummerExists(candidate)) {
      nextNumber++;
      candidate = 'RE-$year-${nextNumber.toString().padLeft(5, '0')}';
    }

    return candidate;
  }

  /// Checks if a rechnungsnummer already exists.
  Future<bool> rechnungsnummerExists(String rechnungsnummer) async {
    final result = await (_db.select(
      _db.beitraege,
    )..where((b) => b.rechnungsnummer.equals(rechnungsnummer))).get();
    return result.isNotEmpty;
  }
}

/// Riverpod provider for [BeitraegeRepository].
@riverpod
BeitraegeRepository beitraegeRepository(Ref ref) {
  return BeitraegeRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(bemerkungRepositoryProvider),
  );
}
