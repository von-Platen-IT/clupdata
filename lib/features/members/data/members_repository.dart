import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/core/data/bemerkung_repository.dart';
import 'package:clupdata/core/providers/database_provider.dart';
import 'package:clupdata/features/members/domain/models/member_row_data.dart';
import 'package:clupdata/features/members/domain/models/leistung_dropdown_item.dart';

part 'members_repository.g.dart';

class MembersRepository {
  final AppDatabase _db;
  final BemerkungRepository _bemerkungRepo;
  MembersRepository(this._db, this._bemerkungRepo);

  Stream<List<Mitglied>> watchMembers() {
    return _db.select(_db.mitglieds).watch();
  }

  /// Streams the full list of [MemberRowData], joined with Leistung and Preis.
  /// Performs the join at the SQL level instead of in Dart, so only relevant
  /// changes trigger a rebuild (Issue 3.1).
  Stream<List<MemberRowData>> watchMembersWithDetails() {
    final query = _db.select(_db.mitglieds).join([
      drift.leftOuterJoin(
        _db.leistung,
        _db.leistung.id.equalsExp(_db.mitglieds.leistungId),
      ),
      drift.leftOuterJoin(
        _db.preis,
        _db.preis.id.equalsExp(_db.mitglieds.preisId),
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final mitglied = row.readTable(_db.mitglieds);
        final leistung = row.readTableOrNull(_db.leistung);
        final preis = row.readTableOrNull(_db.preis);

        return MemberRowData(
          id: mitglied.id,
          name: mitglied.name,
          vorname: mitglied.vorname,
          ort: mitglied.ort,
          plz: mitglied.plz,
          telefon1: mitglied.telefon1,
          telefon2: mitglied.telefon2,
          email: mitglied.email,
          leistungName: leistung?.name,
          vertragLaufzeitVon: mitglied.vertragLaufzeitVon,
          vertragLaufzeitBis: mitglied.vertragLaufzeitBis,
          vertragKontierung: mitglied.vertragKontierung,
          geboren: mitglied.geboren,
          beitrag: preis?.bruttopreis,
        );
      }).toList();
    });
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
    return _bemerkungRepo.getBemerkungById(id);
  }

  Future<void> saveMemberRemark(
    int memberId,
    int? existingBemerkungId,
    String titel,
    String text,
  ) async {
    final bemerkungId = await _bemerkungRepo.saveBemerkung(
      existingBemerkungId,
      titel,
      text,
    );

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

  // ── Lookup Data for Edit Dialog (Issue 4.2) ────────────────────────────
  // These methods decouple the Member edit dialog from the Leistungen
  // feature module by providing lookup data through the own repository.

  /// Streams all available Leistungen for dropdown selection.
  /// Decouples the Member edit dialog from the Leistungen feature module.
  Stream<List<LeistungDropdownItem>> watchLeistungenForDropdown() {
    final query = _db.select(_db.leistung).join([
      drift.innerJoin(_db.preis, _db.preis.id.equalsExp(_db.leistung.preisId)),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final leistung = row.readTable(_db.leistung);
        final preis = row.readTable(_db.preis);
        return LeistungDropdownItem(
          id: leistung.id,
          name: leistung.name,
          bruttopreis: preis.bruttopreis,
        );
      }).toList();
    });
  }

  /// Gets a Preis by its ID.
  /// Decouples the Member edit dialog from the Preise repository.
  Future<PreisItem?> getPreisById(int id) {
    return (_db.select(
      _db.preis,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Adds a new Preis and returns its ID.
  /// Decouples the Member edit dialog from the Preise repository.
  Future<int> addPreis(PreisCompanion companion) {
    return _db.into(_db.preis).insert(companion);
  }

  /// Updates an existing Preis.
  /// Decouples the Member edit dialog from the Preise repository.
  Future<bool> updatePreis(PreisItem preis) {
    return _db.update(_db.preis).replace(preis);
  }
}

@riverpod
MembersRepository membersRepository(Ref ref) {
  return MembersRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(bemerkungRepositoryProvider),
  );
}
