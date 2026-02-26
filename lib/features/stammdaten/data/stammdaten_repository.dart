import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

part 'stammdaten_repository.g.dart';

class StammdatenRepository {
  final AppDatabase _db;
  StammdatenRepository(this._db);

  Stream<List<StammdatenItem>> watchSettings() {
    return _db.select(_db.stammdaten).watch();
  }

  Future<StammdatenItem?> getSetting(String schluessel) async {
    return (_db.select(_db.stammdaten)
          ..where((s) => s.schluessel.equals(schluessel)))
        .getSingleOrNull();
  }

  Future<int> addSetting(StammdatenCompanion setting) async {
    return _db.into(_db.stammdaten).insert(setting);
  }

  Future<bool> updateSetting(StammdatenItem setting) async {
    return _db.update(_db.stammdaten).replace(setting);
  }
}

@riverpod
StammdatenRepository stammdatenRepository(Ref ref) {
  return StammdatenRepository(ref.watch(appDatabaseProvider));
}
