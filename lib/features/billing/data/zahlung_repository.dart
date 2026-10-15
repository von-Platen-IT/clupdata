import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/models/zahlung.dart' as model;
import '../domain/models/zahlungsart.dart';

part 'zahlung_repository.g.dart';

/// Repository für Zahlungseingänge ([`zahlung`](../../../../assets/data/structur.md)).
///
/// Enthält reine DB-Operationen. Die Geschäftslogik (Status-Kaskade)
/// liegt im `ZahlungService`.
class ZahlungRepository {
  ZahlungRepository(this.db);

  final AppDatabase db;

  /// Speichert eine Zahlung und gibt die erzeugte ID zurück.
  Future<int> insertZahlung(ZahlungenCompanion entry) {
    return db.into(db.zahlungen).insert(entry);
  }

  /// Liefert alle Zahlungen zu einem Beitrag, sortiert nach Datum.
  Future<List<model.Zahlung>> ladeZahlungenFuerBeitrag(int beitragId) async {
    final rows = await (db.select(db.zahlungen)
          ..where((z) => z.beitragId.equals(beitragId))
          ..orderBy([(z) => OrderingTerm.asc(z.datum)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Liefert alle Zahlungen zu einer Rechnung, sortiert nach Datum.
  Future<List<model.Zahlung>> ladeZahlungenFuerRechnung(int rechnungId) async {
    final rows = await (db.select(db.zahlungen)
          ..where((z) => z.rechnungId.equals(rechnungId))
          ..orderBy([(z) => OrderingTerm.asc(z.datum)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Summe aller Zahlungen zu einem Beitrag.
  Future<double> summeFuerBeitrag(int beitragId) async {
    final sum = db.zahlungen.betrag.sum();
    final query = db.selectOnly(db.zahlungen)
      ..addColumns([sum])
      ..where(db.zahlungen.beitragId.equals(beitragId));
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  /// Summe aller Zahlungen zu einer Rechnung.
  Future<double> summeFuerRechnung(int rechnungId) async {
    final sum = db.zahlungen.betrag.sum();
    final query = db.selectOnly(db.zahlungen)
      ..addColumns([sum])
      ..where(db.zahlungen.rechnungId.equals(rechnungId));
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  model.Zahlung _toDomain(Zahlung row) {
    return model.Zahlung(
      id: row.id,
      uuid: row.uuid,
      beitragId: row.beitragId,
      rechnungId: row.rechnungId,
      betrag: row.betrag,
      datum: row.datum,
      zahlungsart: Zahlungsart.fromDb(row.zahlungsart),
      bemerkung: row.bemerkung,
      createdAt: row.createdAt,
    );
  }
}

/// Provider für [`ZahlungRepository`].
@riverpod
ZahlungRepository zahlungRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ZahlungRepository(db);
}
