import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/core/providers/database_provider.dart';

part 'members_repository.g.dart';

class MembersRepository {
  final AppDatabase _db;
  MembersRepository(this._db);

  Stream<List<Mitglied>> watchMembers() {
    return _db.select(_db.mitglieds).watch();
  }

  Stream<BemerkungData?> watchBemerkungForMember(int memberId) {
    final query = _db.select(_db.mitglieds).join([
      drift.leftOuterJoin(
        _db.bemerkung,
        _db.bemerkung.id.equalsExp(_db.mitglieds.bemerkungId),
      ),
    ])..where(_db.mitglieds.id.equals(memberId));

    return query.watchSingleOrNull().map(
      (row) => row?.readTableOrNull(_db.bemerkung),
    );
  }

  Future<Mitglied?> getMemberById(int id) {
    return (_db.select(
      _db.mitglieds,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  Future<BemerkungData?> getBemerkungById(int id) {
    return (_db.select(
      _db.bemerkung,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Future<int> saveBemerkung(int? existingId, String titel, String text) async {
    if (existingId != null) {
      await (_db.update(
        _db.bemerkung,
      )..where((b) => b.id.equals(existingId))).write(
        BemerkungCompanion(
          titel: drift.Value(titel),
          textValue: drift.Value(text),
        ),
      );
      return existingId;
    } else {
      return _db
          .into(_db.bemerkung)
          .insert(
            BemerkungCompanion.insert(
              titel: titel,
              textValue: drift.Value(text),
            ),
          );
    }
  }

  Future<void> saveMemberRemark(
    int memberId,
    int? existingBemerkungId,
    String titel,
    String text,
  ) async {
    final bemerkungId = await saveBemerkung(existingBemerkungId, titel, text);

    // Update the member with the new FK if it was newly created
    if (existingBemerkungId == null) {
      await (_db.update(_db.mitglieds)..where((m) => m.id.equals(memberId)))
          .write(MitgliedsCompanion(bemerkungId: drift.Value(bemerkungId)));
    }
  }

  Future<int> addMember(MitgliedsCompanion member) {
    return _db.into(_db.mitglieds).insert(member);
  }

  Future<bool> updateMember(Mitglied member) {
    return _db.update(_db.mitglieds).replace(member);
  }

  Future<int> deleteMember(int id) {
    return (_db.delete(_db.mitglieds)..where((m) => m.id.equals(id))).go();
  }

  /// Gets all members ordered by name.
  Future<List<Mitglied>> getAllMembers() async {
    return (_db.select(
      _db.mitglieds,
    )..orderBy([(m) => drift.OrderingTerm(expression: m.name)])).get();
  }

  /// Searches members by name or first name (case-insensitive).
  /// Returns a list of matching members limited to [limit] results.
  Future<List<Mitglied>> searchMembers(String query, {int limit = 20}) async {
    final lowerQuery = query.toLowerCase();
    return (_db.select(_db.mitglieds)
          ..where(
            (m) =>
                m.name.lower().like('%$lowerQuery%') |
                m.vorname.lower().like('%$lowerQuery%'),
          )
          ..limit(limit))
        .get();
  }

  /// Gets a member with their associated price (Beitrag).
  /// Returns a record of (Mitglied, Preis?) if found.
  Future<(Mitglied?, PreisItem?)> getMemberWithPrice(int memberId) async {
    final member = await getMemberById(memberId);
    if (member == null || member.preisId == null) {
      return (member, null);
    }
    final preis = await (_db.select(
      _db.preis,
    )..where((p) => p.id.equals(member.preisId!))).getSingleOrNull();
    return (member, preis);
  }
}

@riverpod
MembersRepository membersRepository(Ref ref) {
  return MembersRepository(ref.watch(appDatabaseProvider));
}
