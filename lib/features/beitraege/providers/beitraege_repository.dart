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

  /// Streams the [BemerkungData] linked to a [Beitrag] by [beitragId].
  Stream<BemerkungData?> watchBemerkungForBeitrag(int beitragId) {
    final query = _db.select(_db.beitraege).join([
      leftOuterJoin(_db.bemerkung, _db.bemerkung.id.equalsExp(_db.beitraege.bemerkungId)),
    ])..where(_db.beitraege.id.equals(beitragId));
    return query.watchSingleOrNull().map((row) => row?.readTableOrNull(_db.bemerkung));
  }

  /// Streams the full list of [BeitragRowData], joined with Mitglied and Leistung.
  Stream<List<BeitragRowData>> watchBeitraege() {
    final query = _db.select(_db.beitraege).join([
      innerJoin(_db.mitglieds, _db.mitglieds.id.equalsExp(_db.beitraege.mitgliedId)),
      innerJoin(_db.leistung, _db.leistung.id.equalsExp(_db.beitraege.leistungId)),
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
    return (_db.select(_db.beitraege)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Inserts a new Beitrag. Returns the generated [id].
  Future<int> addBeitrag(BeitraegeCompanion beitrag) {
    return _db.into(_db.beitraege).insert(beitrag);
  }

  /// Updates an existing [Beitrag]. Also updates [statusDatum] if status changed.
  Future<void> updateBeitrag(BeitraegeCompanion beitrag) async {
    await (_db.update(_db.beitraege)
          ..where((b) => b.id.equals(beitrag.id.value)))
        .write(beitrag);
  }

  /// Deletes a [Beitrag] by [id].
  Future<int> deleteBeitrag(int id) {
    return (_db.delete(_db.beitraege)..where((b) => b.id.equals(id))).go();
  }

  /// Saves a [BemerkungData] note (insert or update) and returns the [id].
  Future<int> saveBemerkung(int? existingId, String titel, String text) async {
    if (existingId != null) {
      await (_db.update(_db.bemerkung)..where((b) => b.id.equals(existingId))).write(
        BemerkungCompanion(titel: Value(titel), textValue: Value(text)),
      );
      return existingId;
    } else {
      return _db.into(_db.bemerkung).insert(
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
