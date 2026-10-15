import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/models/offener_posten.dart';

part 'offene_posten_repository.g.dart';

/// Repository für die gemeinsame Offene-Posten-Sicht über beide Belegarten
/// ([`beitrag`](../../../../assets/data/structur.md) und
/// [`rechnung`](../../../../assets/data/structur.md)).
///
/// Ein Posten gilt als offen, solange `SUM(zahlungen)` < Forderung und
/// der Status nicht `storniert` ist (Saldo-Prinzip).
class OffenePostenRepository {
  OffenePostenRepository(this.db);

  final AppDatabase db;

  /// Liefert alle offenen Posten (Saldo > 0), sortiert nach Fälligkeit.
  Future<List<OffenerPosten>> ladeOffenePosten({
    bool nurUeberfaellig = false,
  }) async {
    final posten = <OffenerPosten>[];
    final beitragSummen = await _ladeZahlungsSummen(nachBeitrag: true);
    final rechnungSummen = await _ladeZahlungsSummen(nachBeitrag: false);
    final mitgliedNamen = await _ladeMitgliedNamen();

    // Beiträge inkl. Preis-Snapshot (eine Query, kein N+1)
    final beitragQuery = db.select(db.beitraege).join([
      leftOuterJoin(db.preis, db.preis.id.equalsExp(db.beitraege.preisId)),
    ])
      ..where(db.beitraege.status.isNotIn(['bezahlt', 'storniert']));

    for (final row in await beitragQuery.get()) {
      final beitrag = row.readTable(db.beitraege);
      final gezahlt = beitragSummen[beitrag.id] ?? 0;
      // Forderung = Beitragshöhe über den Preis-Snapshot (preisId).
      final forderung = row.readTableOrNull(db.preis)?.bruttopreis ?? 0;
      final rest = _runde(forderung - gezahlt);
      if (rest <= 0.005) continue;

      final posten1 = OffenerPosten(
        belegArt: OffenerPostenArt.beitrag,
        belegId: beitrag.id,
        nummer: beitrag.rechnungsnummer,
        bezeichnung: 'Beitrag',
        kundeName: mitgliedNamen[beitrag.mitgliedId] ?? 'Mitglied #${beitrag.mitgliedId}',
        betrag: forderung,
        saldo: rest,
        faelligAm: beitrag.faelligAm,
        status: beitrag.status,
      );
      if (!nurUeberfaellig || posten1.istUeberfaellig) {
        posten.add(posten1);
      }
    }

    // Rechnungen (Gutschriften mit negativem Betrag ergeben rest <= 0)
    final rechnungQuery = db.select(db.rechnungen)
      ..where((r) => r.status.isNotIn(['bezahlt', 'storniert']));

    for (final rechnung in await rechnungQuery.get()) {
      final gezahlt = rechnungSummen[rechnung.id] ?? 0;
      final rest = _runde(rechnung.betragBrutto - gezahlt);
      if (rest <= 0.005) continue;

      final posten2 = OffenerPosten(
        belegArt: OffenerPostenArt.rechnung,
        belegId: rechnung.id,
        nummer: rechnung.rechnungsnummer,
        bezeichnung: rechnung.kundeName ?? 'Waren-Rechnung',
        kundeName: rechnung.kundeName ??
            mitgliedNamen[rechnung.mitgliedId ?? -1] ??
            'Kunde',
        betrag: rechnung.betragBrutto,
        saldo: rest,
        faelligAm: rechnung.faelligAm,
        status: rechnung.status,
      );
      if (!nurUeberfaellig || posten2.istUeberfaellig) {
        posten.add(posten2);
      }
    }

    posten.sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
    return posten;
  }

  /// Summiert die Zahlungen je Beleg (`beleg_id → SUM(betrag)`).
  Future<Map<int, double>> _ladeZahlungsSummen({required bool nachBeitrag}) async {
    final belegId = nachBeitrag ? db.zahlungen.beitragId : db.zahlungen.rechnungId;
    final summe = db.zahlungen.betrag.sum();
    final query = db.selectOnly(db.zahlungen)
      ..addColumns([belegId, summe])
      ..where(belegId.isNotNull())
      ..groupBy([belegId]);
    return {
      for (final row in await query.get())
        row.read(belegId)!: row.read(summe) ?? 0,
    };
  }

  /// Lädt `id → "Name, Vorname"` für alle Mitglieder.
  Future<Map<int, String>> _ladeMitgliedNamen() async {
    final rows = await db.select(db.mitglieds).get();
    return {
      for (final m in rows) m.id: '${m.name}, ${m.vorname}',
    };
  }

  double _runde(double wert) => (wert * 100).roundToDouble() / 100;
}

/// Provider für [`OffenePostenRepository`].
@riverpod
OffenePostenRepository offenePostenRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return OffenePostenRepository(db);
}
