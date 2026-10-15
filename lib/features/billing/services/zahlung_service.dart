import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/models/zahlungsart.dart';

part 'zahlung_service.g.dart';

/// Ergebnis einer Zahlungsbuchung.
class ZahlungBuchungResult {
  const ZahlungBuchungResult({
    required this.zahlungId,
    required this.neuerStatus,
    required this.saldo,
    required this.forderung,
  });

  final int zahlungId;
  final String neuerStatus;
  final double saldo;
  final double forderung;

  bool get istVollstaendigBezahlt => saldo <= 0.005;
}

/// Service für Zahlungseingänge und die automatische Status-Kaskade.
///
/// **Einzige Stelle**, die [`zahlung`](../../../../assets/data/structur.md)
/// schreibt und daraus den Belegstatus ableitet (Saldo-Prinzip):
/// - Saldo == 0 → `bezahlt`
/// - Saldo > 0 → `teilbezahlt`
///
/// Statuswechsel werden in der passenden Status-Historie protokolliert
/// ([`beitrag_status_verlauf`](../../../../assets/data/structur.md) bzw.
/// [`rechnung_status_verlauf`](../../../../assets/data/structur.md)).
class ZahlungService {
  ZahlungService(this.db);

  final AppDatabase db;

  /// Buchte eine Zahlung für einen Beitrag.
  ///
  /// Die Buchung läuft atomar: Zahlungs-Eintrag, Statuswechsel und
  /// Status-Verlauf erfolgen in einer Transaktion.
  Future<ZahlungBuchungResult> bucheZahlungFuerBeitrag({
    required int beitragId,
    required double betrag,
    required Zahlungsart zahlungsart,
    DateTime? datum,
    String? bemerkung,
  }) async {
    final zahlungsDatum = datum ?? DateTime.now();
    _pruefeBetrag(betrag);

    return db.transaction(() async {
      final vorhanden = await (db.select(db.beitraege)
            ..where((b) => b.id.equals(beitragId)))
          .getSingleOrNull();
      if (vorhanden == null) {
        throw StateError('Beitrag $beitragId nicht gefunden.');
      }
      if (vorhanden.status == 'storniert') {
        throw StateError('Auf stornierte Belege können keine Zahlungen gebucht werden.');
      }

      final zahlungId = await db
          .into(db.zahlungen)
          .insert(
            ZahlungenCompanion.insert(
              beitragId: Value(beitragId),
              betrag: betrag,
              datum: zahlungsDatum,
              zahlungsart: zahlungsart.name,
              bemerkung: Value(bemerkung),
            ),
          );

      final beitrag = await (db.select(db.beitraege)
            ..where((b) => b.id.equals(beitragId)))
          .getSingle();
      final forderung = await _ladeBeitragsForderung(beitragId);
      final gezahlt = await _summeZahlungen(beitragId: beitragId);
      final saldo = _runde(forderung - gezahlt);

      final neuerStatus = saldo <= 0.005 ? 'bezahlt' : 'teilbezahlt';
      await _aktualisiereBeitragStatus(
        beitrag,
        neuerStatus,
        zahlungsDatum,
        'Zahlung gebucht (${zahlungsart.label}, ${betrag.toStringAsFixed(2)} €)',
      );

      return ZahlungBuchungResult(
        zahlungId: zahlungId,
        neuerStatus: neuerStatus,
        saldo: saldo,
        forderung: forderung,
      );
    });
  }

  /// Buchte eine Zahlung für eine Waren-Rechnung.
  Future<ZahlungBuchungResult> bucheZahlungFuerRechnung({
    required int rechnungId,
    required double betrag,
    required Zahlungsart zahlungsart,
    DateTime? datum,
    String? bemerkung,
  }) async {
    final zahlungsDatum = datum ?? DateTime.now();
    _pruefeBetrag(betrag);

    return db.transaction(() async {
      final vorhanden = await (db.select(db.rechnungen)
            ..where((r) => r.id.equals(rechnungId)))
          .getSingleOrNull();
      if (vorhanden == null) {
        throw StateError('Rechnung $rechnungId nicht gefunden.');
      }
      if (vorhanden.status == 'storniert') {
        throw StateError('Auf stornierte Belege können keine Zahlungen gebucht werden.');
      }

      final zahlungId = await db
          .into(db.zahlungen)
          .insert(
            ZahlungenCompanion.insert(
              rechnungId: Value(rechnungId),
              betrag: betrag,
              datum: zahlungsDatum,
              zahlungsart: zahlungsart.name,
              bemerkung: Value(bemerkung),
            ),
          );

      final rechnung = await (db.select(db.rechnungen)
            ..where((r) => r.id.equals(rechnungId)))
          .getSingle();
      final forderung = rechnung.betragBrutto;
      final gezahlt = await _summeZahlungen(rechnungId: rechnungId);
      final saldo = _runde(forderung - gezahlt);

      final neuerStatus = saldo <= 0.005 ? 'bezahlt' : 'teilbezahlt';
      await _aktualisiereRechnungStatus(
        rechnung,
        neuerStatus,
        zahlungsDatum,
        'Zahlung gebucht (${zahlungsart.label}, ${betrag.toStringAsFixed(2)} €)',
      );

      return ZahlungBuchungResult(
        zahlungId: zahlungId,
        neuerStatus: neuerStatus,
        saldo: saldo,
        forderung: forderung,
      );
    });
  }

  /// Berechnet den offenen Saldo eines Beitrags.
  Future<double> berechneSaldoBeitrag(int beitragId) async {
    final forderung = await _ladeBeitragsForderung(beitragId);
    final gezahlt = await _summeZahlungen(beitragId: beitragId);
    return _runde(forderung - gezahlt);
  }

  /// Berechnet den offenen Saldo einer Rechnung.
  Future<double> berechneSaldoRechnung(int rechnungId) async {
    final rechnung = await (db.select(db.rechnungen)
          ..where((r) => r.id.equals(rechnungId)))
        .getSingle();
    final gezahlt = await _summeZahlungen(rechnungId: rechnungId);
    return _runde(rechnung.betragBrutto - gezahlt);
  }

  Future<double> _summeZahlungen({int? beitragId, int? rechnungId}) async {
    final sum = db.zahlungen.betrag.sum();
    final query = db.selectOnly(db.zahlungen)..addColumns([sum]);
    if (beitragId != null) {
      query.where(db.zahlungen.beitragId.equals(beitragId));
    } else {
      query.where(db.zahlungen.rechnungId.equals(rechnungId!));
    }
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  Future<double> _ladeBeitragsForderung(int beitragId) async {
    final query = db.select(db.beitraege).join([
      leftOuterJoin(db.preis, db.preis.id.equalsExp(db.beitraege.preisId)),
    ])
      ..where(db.beitraege.id.equals(beitragId));
    final row = await query.getSingle();
    return row.readTableOrNull(db.preis)?.bruttopreis ?? 0;
  }

  Future<void> _aktualisiereBeitragStatus(
    Beitrag beitrag,
    String neuerStatus,
    DateTime datum,
    String bemerkung,
  ) async {
    await (db.update(db.beitraege)..where((b) => b.id.equals(beitrag.id)))
        .write(
      BeitraegeCompanion(
        status: Value(neuerStatus),
        statusDatum: Value(datum),
      ),
    );
    await db
        .into(db.beitragStatusVerlauf)
        .insert(
          BeitragStatusVerlaufCompanion.insert(
            beitragId: beitrag.id,
            status: neuerStatus,
            geaendertAm: datum,
            bemerkung: bemerkung,
          ),
        );
  }

  Future<void> _aktualisiereRechnungStatus(
    Rechnung rechnung,
    String neuerStatus,
    DateTime datum,
    String bemerkung,
  ) async {
    await (db.update(db.rechnungen)..where((r) => r.id.equals(rechnung.id)))
        .write(
      RechnungenCompanion(
        status: Value(neuerStatus),
        bezahltAm: neuerStatus == 'bezahlt'
            ? Value(datum)
            : const Value.absent(),
      ),
    );
    await db
        .into(db.rechnungStatusVerlaeufe)
        .insert(
          RechnungStatusVerlaeufeCompanion.insert(
            rechnungId: rechnung.id,
            status: neuerStatus,
            geaendertAm: datum,
            bemerkung: bemerkung,
          ),
        );
  }

  /// Zahlungsbeträge müssen positiv sein.
  void _pruefeBetrag(double betrag) {
    if (betrag <= 0) {
      throw ArgumentError.value(betrag, 'betrag', 'Betrag muss größer als 0 sein.');
    }
  }

  double _runde(double wert) => (wert * 100).roundToDouble() / 100;
}

/// Provider für [`ZahlungService`].
@riverpod
ZahlungService zahlungService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ZahlungService(db);
}
