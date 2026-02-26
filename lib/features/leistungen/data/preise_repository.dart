import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

part 'preise_repository.g.dart';

class PreiseRepository {
  final AppDatabase _db;
  PreiseRepository(this._db);

  Stream<List<PreisItem>> watchPreise() {
    return _db.select(_db.preis).watch();
  }

  Future<int> addPreis(PreisCompanion price) async {
    return _db.into(_db.preis).insert(price);
  }

  Future<bool> updatePreis(PreisItem price) async {
    return _db.update(_db.preis).replace(price);
  }

  Future<int> deletePreis(int id) async {
    return (_db.delete(_db.preis)..where((p) => p.id.equals(id))).go();
  }
}

@riverpod
PreiseRepository preiseRepository(Ref ref) {
  return PreiseRepository(ref.watch(appDatabaseProvider));
}
