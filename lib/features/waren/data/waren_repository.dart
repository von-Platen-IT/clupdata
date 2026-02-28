import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

part 'waren_repository.g.dart';

class WarenDetail {
  final WarenItem ware;
  final BemerkungData? bemerkung;

  WarenDetail(this.ware, this.bemerkung);
}

class WarenRepository {
  final AppDatabase _db;
  WarenRepository(this._db);

  Stream<List<WarenDetail>> watchWarenDetails() {
    final query = _db.select(_db.waren).join([
      drift.leftOuterJoin(_db.bemerkung, _db.bemerkung.id.equalsExp(_db.waren.bemerkungId)),
    ]);
    
    return query.watch().map((rows) {
      return rows.map((row) {
        return WarenDetail(
          row.readTable(_db.waren),
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

  Future<void> saveWareFull({
    int? wareId,
    required String bezeichnung,
    String? beschreibung,
    String? kategorie,
    String? groesse,
    String? farbe,
    String? geschlecht,
    String? material,
    double? einkaufspreis,
    required double bruttopreis,
    required int bestand,
    required int mindestbestand,
    String? lieferant,
    String? hersteller,
    String? herstellerArtikelnr,
    double? gewichtKg,
    String? einheit,
    required bool aktiv,
    int? existingBemerkungId,
    required String bemerkungTitel,
    required String bemerkungText,
  }) async {
    // 1. Save Bemerkung
    int? bemerkungId = existingBemerkungId;
    if (bemerkungTitel.isNotEmpty || bemerkungText.isNotEmpty) {
       bemerkungId = await _saveBemerkungBaseLogic(existingBemerkungId, bemerkungTitel, bemerkungText);
    }
    
    // 2. Save Ware
    final companion = WarenCompanion(
      bezeichnung: drift.Value(bezeichnung),
      beschreibung: drift.Value(beschreibung),
      kategorie: drift.Value(kategorie),
      groesse: drift.Value(groesse),
      farbe: drift.Value(farbe),
      geschlecht: drift.Value(geschlecht),
      material: drift.Value(material),
      einkaufspreis: drift.Value(einkaufspreis),
      bruttopreis: drift.Value(bruttopreis),
      bestand: drift.Value(bestand),
      mindestbestand: drift.Value(mindestbestand),
      lieferant: drift.Value(lieferant),
      hersteller: drift.Value(hersteller),
      herstellerArtikelnr: drift.Value(herstellerArtikelnr),
      gewichtKg: drift.Value(gewichtKg),
      einheit: drift.Value(einheit),
      aktiv: drift.Value(aktiv),
      bemerkungId: drift.Value(bemerkungId),
      aktualisiertAm: drift.Value(DateTime.now()),
    );

    if (wareId != null) {
      await (_db.update(_db.waren)..where((w) => w.id.equals(wareId))).write(companion);
    } else {
      await _db.into(_db.waren).insert(companion);
    }
  }

  Future<void> saveWareRemark(int wareId, int? existingBemerkungId, String titel, String text) async {
    final bemerkungId = await _saveBemerkungBaseLogic(existingBemerkungId, titel, text);
    
    if (existingBemerkungId == null) {
      await (_db.update(_db.waren)..where((w) => w.id.equals(wareId))).write(
        WarenCompanion(bemerkungId: drift.Value(bemerkungId))
      );
    }
  }

  Future<int> deleteWare(int id) async {
    return (_db.delete(_db.waren)..where((w) => w.id.equals(id))).go();
  }
}

@riverpod
WarenRepository warenRepository(Ref ref) {
  return WarenRepository(ref.watch(appDatabaseProvider));
}
