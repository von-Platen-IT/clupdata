import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

part 'leistungen_repository.g.dart';

class LeistungsDetail {
  final LeistungItem leistung;
  final PreisItem preis;
  final BemerkungData? bemerkung;

  LeistungsDetail(this.leistung, this.preis, this.bemerkung);
}

class LeistungenRepository {
  final AppDatabase _db;
  LeistungenRepository(this._db);

  Stream<List<LeistungItem>> watchLeistungen() {
    return _db.select(_db.leistung).watch();
  }

  Stream<List<LeistungsDetail>> watchLeistungenDetails() {
    final query = _db.select(_db.leistung).join([
      drift.innerJoin(_db.preis, _db.preis.id.equalsExp(_db.leistung.preisId)),
      drift.leftOuterJoin(_db.bemerkung, _db.bemerkung.id.equalsExp(_db.leistung.bemerkungId)),
    ]);
    
    return query.watch().map((rows) {
      return rows.map((row) {
        return LeistungsDetail(
          row.readTable(_db.leistung),
          row.readTable(_db.preis),
          row.readTableOrNull(_db.bemerkung),
        );
      }).toList();
    });
  }

  Future<int> _saveBemerkungBaseLogic(int? existingId, String titel, String text) async {
    if (existingId != null) {
      await (_db.update(_db.bemerkung)..where((b) => b.id.equals(existingId))).write(
        BemerkungCompanion(
          titel: drift.Value(titel),
          textValue: drift.Value(text),
        ),
      );
      return existingId;
    } else {
      return _db.into(_db.bemerkung).insert(
        BemerkungCompanion.insert(
          titel: titel,
          textValue: drift.Value(text),
        ),
      );
    }
  }

  Future<void> saveLeistungFull({
    int? leistungId,
    required String name,
    required String laufzeit,
    int? existingPreisId,
    required double bruttopreis,
    int? existingBemerkungId,
    required String bemerkungTitel,
    required String bemerkungText,
  }) async {
    // 1. Save Bemerkung
    int? bemerkungId = existingBemerkungId;
    if (bemerkungTitel.isNotEmpty || bemerkungText.isNotEmpty) {
       bemerkungId = await _saveBemerkungBaseLogic(existingBemerkungId, bemerkungTitel, bemerkungText);
    }
    
    // 2. Save Preis
    int preisId;
    if (existingPreisId != null) {
      await (_db.update(_db.preis)..where((p) => p.id.equals(existingPreisId))).write(
        PreisCompanion(bruttopreis: drift.Value(bruttopreis))
      );
      preisId = existingPreisId;
    } else {
      preisId = await _db.into(_db.preis).insert(PreisCompanion.insert(bruttopreis: bruttopreis));
    }

    // 3. Save Leistung
    if (leistungId != null) {
      await _db.update(_db.leistung).replace(LeistungItem(
        id: leistungId,
        name: name,
        preisId: preisId,
        laufzeit: laufzeit,
        bemerkungId: bemerkungId,
      ));
    } else {
      await _db.into(_db.leistung).insert(LeistungCompanion.insert(
        name: name,
        preisId: preisId,
        laufzeit: laufzeit,
        bemerkungId: drift.Value(bemerkungId),
      ));
    }
  }

  Future<void> saveLeistungRemark(int leistungId, int? existingBemerkungId, String titel, String text) async {
    final bemerkungId = await _saveBemerkungBaseLogic(existingBemerkungId, titel, text);
    
    if (existingBemerkungId == null) {
      await (_db.update(_db.leistung)..where((l) => l.id.equals(leistungId))).write(
        LeistungCompanion(bemerkungId: drift.Value(bemerkungId))
      );
    }
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
