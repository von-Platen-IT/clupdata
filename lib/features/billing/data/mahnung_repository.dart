import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/models/mahnung.dart' as model;

part 'mahnung_repository.g.dart';

/// Repository für dokumentierte Mahnstufen ([`mahnung`](../../../../assets/data/structur.md)).
class MahnungRepository {
  MahnungRepository(this.db);

  final AppDatabase db;

  /// Speichert eine Mahnung und gibt die erzeugte ID zurück.
  Future<int> insertMahnung(MahnungenCompanion entry) {
    return db.into(db.mahnungen).insert(entry);
  }

  /// Liefert alle Mahnungen zu einem Beitrag, sortiert nach Datum.
  Future<List<model.Mahnung>> ladeMahnungenFuerBeitrag(int beitragId) async {
    final rows = await (db.select(db.mahnungen)
          ..where((m) => m.beitragId.equals(beitragId))
          ..orderBy([(m) => OrderingTerm.asc(m.datum)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Liefert alle Mahnungen zu einer Rechnung, sortiert nach Datum.
  Future<List<model.Mahnung>> ladeMahnungenFuerRechnung(int rechnungId) async {
    final rows = await (db.select(db.mahnungen)
          ..where((m) => m.rechnungId.equals(rechnungId))
          ..orderBy([(m) => OrderingTerm.asc(m.datum)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Höchste bisher dokumentierte Mahnstufe zu einem Beitrag (0 = keine).
  Future<int> letzteStufeFuerBeitrag(int beitragId) async {
    final stufe = db.mahnungen.stufe.max();
    final query = db.selectOnly(db.mahnungen)
      ..addColumns([stufe])
      ..where(db.mahnungen.beitragId.equals(beitragId));
    final row = await query.getSingle();
    return row.read(stufe) ?? 0;
  }

  /// Höchste bisher dokumentierte Mahnstufe zu einer Rechnung (0 = keine).
  Future<int> letzteStufeFuerRechnung(int rechnungId) async {
    final stufe = db.mahnungen.stufe.max();
    final query = db.selectOnly(db.mahnungen)
      ..addColumns([stufe])
      ..where(db.mahnungen.rechnungId.equals(rechnungId));
    final row = await query.getSingle();
    return row.read(stufe) ?? 0;
  }

  model.Mahnung _toDomain(Mahnung row) {
    return model.Mahnung(
      id: row.id,
      uuid: row.uuid,
      beitragId: row.beitragId,
      rechnungId: row.rechnungId,
      stufe: row.stufe,
      datum: row.datum,
      gebuehr: row.gebuehr,
      forderung: row.forderung,
      bemerkung: row.bemerkung,
    );
  }
}

/// Provider für [`MahnungRepository`].
@riverpod
MahnungRepository mahnungRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return MahnungRepository(db);
}
