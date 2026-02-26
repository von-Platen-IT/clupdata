import 'package:drift/drift.dart';
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

  Future<int> addMember(MitgliedsCompanion member) async {
    return _db.into(_db.mitglieds).insert(member);
  }

  Future<bool> updateMember(Mitglied member) async {
    return _db.update(_db.mitglieds).replace(member);
  }

  Future<int> deleteMember(int id) async {
    return (_db.delete(_db.mitglieds)..where((m) => m.id.equals(id))).go();
  }
}

@riverpod
MembersRepository membersRepository(Ref ref) {
  return MembersRepository(ref.watch(appDatabaseProvider));
}
