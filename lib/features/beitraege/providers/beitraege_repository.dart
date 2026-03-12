import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/core/providers/database_provider.dart';

part 'beitraege_repository.g.dart';

/// Data class holding a joined Beitrag with its related names for display.
class BeitragRowData {
  final Beitrag beitrag;
  final String mitgliedName;
  final String leistungName;

  const BeitragRowData({
    required this.beitrag,
    required this.mitgliedName,
    required this.leistungName,
  });
}

/// Repository for all database operations on the [Beitraege] table.
class BeitraegeRepository {
  final AppDatabase _db;
  BeitraegeRepository(this._db);

  // ── Bemerkung ─────────────────────────────────────────────────────────────

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
        beitrag.status.value != current.status;

    await (_db.update(
      _db.beitraege,
    )..where((b) => b.id.equals(beitrag.id.value))).write(beitrag);

    if (statusChanged) {
      await _addStatusEintrag(
        beitragId: beitrag.id.value,
        status: beitrag.status.value,
        bemerkung: statusBemerkung ?? 'Status geändert',
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

  // ── Bemerkung generic ─────────────────────────────────────────────────────

  /// Saves a [BemerkungData] note (insert or update) and returns the [id].
  Future<int> saveBemerkung(int? existingId, String titel, String text) async {
    if (existingId != null) {
      await (_db.update(
        _db.bemerkung,
      )..where((b) => b.id.equals(existingId))).write(
        BemerkungCompanion(titel: Value(titel), textValue: Value(text)),
      );
      return existingId;
    } else {
      return _db
          .into(_db.bemerkung)
          .insert(
            BemerkungCompanion.insert(titel: titel, textValue: Value(text)),
          );
    }
  }
}

/// Riverpod provider for [BeitraegeRepository].
@riverpod
BeitraegeRepository beitraegeRepository(Ref ref) {
  return BeitraegeRepository(ref.watch(appDatabaseProvider));
}

/// Stream provider exposing the joined Beiträge list.
@riverpod
Stream<List<BeitragRowData>> beitraegeList(Ref ref) {
  return ref.watch(beitraegeRepositoryProvider).watchBeitraege();
}
