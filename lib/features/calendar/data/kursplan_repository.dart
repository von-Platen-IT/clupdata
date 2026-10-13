import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/models/kurs_row_data.dart';
import '../domain/models/kursplan_row_data.dart';
import '../domain/models/kursplan_termin_row_data.dart';
import '../domain/wochen_utils.dart';

part 'kursplan_repository.g.dart';

/// Repository für Kurse, Kurspläne und Kurstermine.
///
/// Geschäftsregeln (siehe `plans/kursplan.md`):
/// - `gueltigVon`/`gueltigBis` werden auf Montage normalisiert
/// - `kursplan_termin.kursplan_id` CASCADE, `kurs_id` RESTRICT
/// - Plan-Ermittlung: `gueltigVon <= montag` UND (`gueltigBis` NULL oder `>= montag`)
class KursplanRepository {
  final AppDatabase db;

  KursplanRepository(this.db);

  // ── Kurse ──────────────────────────────────────────────────────────────

  /// Stream aller Kurse, sortiert nach Name.
  Stream<List<KursRowData>> watchKurse() {
    return (db.select(
      db.kurs,
    )..orderBy([(k) => OrderingTerm.asc(k.name)])).watch().map(
      (items) => [
        for (final k in items)
          KursRowData(
            id: k.id,
            name: k.name,
            kampfsportart: k.kampfsportart,
            farbe: k.farbe,
          ),
      ],
    );
  }

  /// Erstellt einen Kurs und liefert die neue ID.
  Future<int> createKurs({
    required String name,
    required String kampfsportart,
    required String farbe,
  }) {
    return db
        .into(db.kurs)
        .insert(
          KursCompanion.insert(
            name: name,
            kampfsportart: kampfsportart,
            farbe: farbe,
          ),
        );
  }

  /// Aktualisiert einen Kurs.
  Future<void> updateKurs(KursRowData kurs) async {
    await (db.update(db.kurs)..where((k) => k.id.equals(kurs.id))).write(
      KursCompanion(
        name: Value(kurs.name),
        kampfsportart: Value(kurs.kampfsportart),
        farbe: Value(kurs.farbe),
      ),
    );
  }

  /// Löscht einen Kurs.
  ///
  /// Wirft eine Exception, solange Kurstermine existieren (FK RESTRICT).
  Future<void> deleteKurs(int id) async {
    await (db.delete(db.kurs)..where((k) => k.id.equals(id))).go();
  }

  // ── Kurspläne ──────────────────────────────────────────────────────────

  /// Stream aller Kurspläne, sortiert nach Gültigkeitsbeginn (absteigend).
  Stream<List<KursplanRowData>> watchKursplaene() {
    return (db.select(
      db.kursplan,
    )..orderBy([(p) => OrderingTerm.desc(p.gueltigVon)])).watch().map(
      (items) => [
        for (final p in items)
          KursplanRowData(
            id: p.id,
            name: p.name,
            gueltigVon: p.gueltigVon,
            gueltigBis: p.gueltigBis,
          ),
      ],
    );
  }

  /// Speichert einen Kursplan inklusive Termine **atomar**.
  ///
  /// [bestehend] = `null` → neuer Plan, sonst Update.
  /// `gueltigVon`/`gueltigBis` werden auf Montage normalisiert.
  /// Die Termine werden vollständig ersetzt (ein Savepoint pro Termin).
  Future<int> saveKursplan({
    KursplanRowData? bestehend,
    required String name,
    required DateTime gueltigVon,
    DateTime? gueltigBis,
    required List<KursplanTermineCompanion> termine,
  }) {
    return db.transaction(() async {
      int id;
      final von = montagVon(gueltigVon);
      final bis = gueltigBis == null ? null : montagVon(gueltigBis);

      if (bestehend == null) {
        id = await db
            .into(db.kursplan)
            .insert(
              KursplanCompanion.insert(
                name: name,
                gueltigVon: von,
                gueltigBis: Value(bis),
              ),
            );
      } else {
        id = bestehend.id;
        await (db.update(db.kursplan)..where((p) => p.id.equals(id))).write(
          KursplanCompanion(
            name: Value(name),
            gueltigVon: Value(von),
            gueltigBis: Value(bis),
          ),
        );
      }

      await replaceTermine(id, termine);
      return id;
    });
  }

  /// Löscht einen Kursplan inklusive aller Termine (CASCADE).
  Future<void> deleteKursplan(int id) async {
    await (db.delete(db.kursplan)..where((p) => p.id.equals(id))).go();
  }

  /// Liefert alle für die Woche um [datum] gültigen Pläne.
  ///
  /// Sortierung: spätester `gueltigVon` zuerst – bei Überschneidungen gewinnt
  /// der zuletzt begonnene Plan.
  Future<List<KursplanRowData>> loadGueltigePlaene(DateTime datum) async {
    final montag = montagVon(datum);
    final query = db.select(db.kursplan)
      ..where(
        (p) =>
            p.gueltigVon.isSmallerOrEqualValue(montag) &
            (p.gueltigBis.isNull() | p.gueltigBis.isBiggerOrEqualValue(montag)),
      )
      ..orderBy([(p) => OrderingTerm.desc(p.gueltigVon)]);
    return (await query.get())
        .map(
          (p) => KursplanRowData(
            id: p.id,
            name: p.name,
            gueltigVon: p.gueltigVon,
            gueltigBis: p.gueltigBis,
          ),
        )
        .toList();
  }

  // ── Termine ────────────────────────────────────────────────────────────

  /// Liefert alle Termine eines Plans, angereichert mit Kursdaten.
  Future<List<KursplanTerminRowData>> loadTermine(int kursplanId) async {
    final query = db.select(db.kursplanTermine).join([
      innerJoin(db.kurs, db.kurs.id.equalsExp(db.kursplanTermine.kursId)),
    ])..where(db.kursplanTermine.kursplanId.equals(kursplanId));

    final rows = await query.get();
    return rows.map((row) {
      final t = row.readTable(db.kursplanTermine);
      final k = row.readTable(db.kurs);
      return KursplanTerminRowData(
        id: t.id,
        kursplanId: t.kursplanId,
        kursId: t.kursId,
        kursName: k.name,
        kampfsportart: k.kampfsportart,
        farbe: k.farbe,
        wochentag: t.wochentag,
        startzeit: t.startzeit,
        endezeit: t.endezeit,
      );
    }).toList();
  }

  /// Ersetzt alle Termine eines Plans atomar (für den Termin-Editor).
  Future<void> replaceTermine(
    int kursplanId,
    List<KursplanTermineCompanion> termine,
  ) async {
    await db.transaction(() async {
      await (db.delete(
        db.kursplanTermine,
      )..where((t) => t.kursplanId.equals(kursplanId))).go();
      for (final t in termine) {
        await db
            .into(db.kursplanTermine)
            .insert(t.copyWith(kursplanId: Value(kursplanId)));
      }
    });
  }

  /// Normalisiert die Gültigkeitsfelder auf Wochenanfänge (Montage).
  KursplanCompanion _normalisiert(KursplanCompanion eintrag) {
    final von = eintrag.gueltigVon.present
        ? Value(montagVon(eintrag.gueltigVon.value))
        : eintrag.gueltigVon;
    final bis = eintrag.gueltigBis.present && eintrag.gueltigBis.value != null
        ? Value(montagVon(eintrag.gueltigBis.value!))
        : eintrag.gueltigBis;
    return eintrag.copyWith(gueltigVon: von, gueltigBis: bis);
  }
}

/// Riverpod provider for [KursplanRepository].
@riverpod
KursplanRepository kursplanRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return KursplanRepository(db);
}
