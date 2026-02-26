import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

part 'leistungen_repository.g.dart';

class LeistungenRepository {
  final AppDatabase _db;
  LeistungenRepository(this._db);

  Stream<List<LeistungItem>> watchLeistungen() {
    return _db.select(_db.leistung).watch();
  }

  Future<int> addLeistung(LeistungCompanion service) async {
    return _db.into(_db.leistung).insert(service);
  }

  Future<bool> updateLeistung(LeistungItem service) async {
    return _db.update(_db.leistung).replace(service);
  }

  Future<int> deleteLeistung(int id) async {
    return (_db.delete(_db.leistung)..where((l) => l.id.equals(id))).go();
  }
}

@riverpod
LeistungenRepository leistungenRepository(Ref ref) {
  return LeistungenRepository(ref.watch(appDatabaseProvider));
}
