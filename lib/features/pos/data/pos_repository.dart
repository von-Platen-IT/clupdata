import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/rechnungsnummer_generator.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/datum_utils.dart';
import '../../billing/domain/models/zahlungsart.dart';
import '../../billing/services/zahlung_service.dart';
import '../../rechnungen/data/rechnungen_repository.dart';

part 'pos_repository.g.dart';

/// Eine Position im Warenkorb der Kasse.
class PosPosition {
  const PosPosition({
    required this.wareId,
    required this.bezeichnung,
    required this.menge,
    required this.einzelpreisBrutto,
    this.mwstSatz = 19,
  });

  final int wareId;
  final String bezeichnung;
  final double menge;
  final double einzelpreisBrutto;
  final double mwstSatz;

  double get gesamtBrutto => menge * einzelpreisBrutto;
  double get gesamtNetto => gesamtBrutto / (1 + mwstSatz / 100);
}

/// Ergebnis eines Kassenvorgangs.
class PosVorgangResult {
  const PosVorgangResult({
    required this.rechnungId,
    required this.rechnungsnummer,
    required this.gesamtBrutto,
    required this.status,
    required this.bestandsAbgezogen,
  });

  final int rechnungId;
  final String rechnungsnummer;
  final double gesamtBrutto;
  final String status;
  final bool bestandsAbgezogen;

  bool get istBezahlt => status == 'bezahlt';
}

/// Zusammenfassung eines Tagesabschlusses (Kassenbericht).
class Tagesabschluss {
  const Tagesabschluss({
    required this.datum,
    required this.anzahlVorgaenge,
    required this.summeBar,
    required this.summeKarte,
    required this.summeRechnung,
  });

  final DateTime datum;
  final int anzahlVorgaenge;
  final double summeBar;
  final double summeKarte;
  final double summeRechnung;

  double get summeKasse => summeBar + summeKarte;
  double get summeGesamt => summeKasse + summeRechnung;
}

/// Repository für den Kassenbetrieb (POS).
///
/// Ein Kassenvorgang erzeugt eine [`rechnung`](../../../../assets/data/structur.md)
/// mit Positionen. Regeln (siehe [`plans/rechnungsstellung-redesign.md`](../../../../plans/rechnungsstellung-redesign.md)):
/// - **Bar/Karte** → Rechnung `bezahlt` + [`zahlung`](../../../../assets/data/structur.md) + **Bestandsabzug**
/// - **Rechnung** → Status `offen` + Fälligkeit, **kein** Bestandsabzug
///   (Rechnungsstellung ist kein Kassenvorgang)
class PosRepository {
  PosRepository(this.db, this._rechnungen, this._zahlungen);

  final AppDatabase db;
  final RechnungenRepository _rechnungen;
  final ZahlungService _zahlungen;

  /// Führt einen Kassenvorgang atomar aus.
  Future<PosVorgangResult> kassiereVorgang({
    required List<PosPosition> positionen,
    required Zahlungsart zahlungsart,
    int? mitgliedId,
    String? kundeName,
  }) async {
    assert(positionen.isNotEmpty, 'Warenkorb darf nicht leer sein');

    final jetzt = DateTime.now();
    final gesamtBrutto = positionen.fold<double>(
      0,
      (sum, p) => sum + p.gesamtBrutto,
    );
    final gesamtNetto = positionen.fold<double>(
      0,
      (sum, p) => sum + p.gesamtNetto,
    );
    final gesamtMwst = gesamtBrutto - gesamtNetto;
    final sofortBezahlt =
        zahlungsart == Zahlungsart.bar || zahlungsart == Zahlungsart.karte;

    return db.transaction(() async {
      final rechnungsnummer = await RechnungsnummerGenerator(
        db,
      ).generateForRechnung();

      final rechnungId = await _rechnungen.addRechnung(
        RechnungenCompanion.insert(
          rechnungsnummer: rechnungsnummer,
          mitgliedId: Value(mitgliedId),
          kundeName: Value(kundeName),
          status: sofortBezahlt ? 'offen' : 'offen',
          datum: jetzt,
          faelligAm: addiereTage(jetzt, 14),
          betragNetto: gesamtNetto,
          betragBrutto: gesamtBrutto,
          betragMwst: gesamtMwst,
        ),
        [
          // rechnungId/positionNr setzt addRechnung() selbst.
          for (final p in positionen)
            RechnungPositionenCompanion(
              warenId: Value(p.wareId),
              bezeichnung: Value(p.bezeichnung),
              menge: Value(p.menge),
              einzelpreisNetto: Value(
                p.einzelpreisBrutto / (1 + p.mwstSatz / 100),
              ),
              einzelpreisBrutto: Value(p.einzelpreisBrutto),
              mwstSatz: Value(p.mwstSatz),
              gesamtNetto: Value(p.gesamtNetto),
              gesamtBrutto: Value(p.gesamtBrutto),
            ),
        ],
      );

      // Initialer Status-Verlauf
      await db
          .into(db.rechnungStatusVerlaeufe)
          .insert(
            RechnungStatusVerlaeufeCompanion.insert(
              rechnungId: rechnungId,
              status: 'offen',
              geaendertAm: jetzt,
              bemerkung: sofortBezahlt
                  ? 'Kassenvorgang (${zahlungsart.label})'
                  : 'Verkauf auf Rechnung',
            ),
          );

      var bestandsAbgezogen = false;
      if (sofortBezahlt) {
        // Zahlung buchen → Status-Kaskade setzt automatisch `bezahlt`.
        await _zahlungen.bucheZahlungFuerRechnung(
          rechnungId: rechnungId,
          betrag: gesamtBrutto,
          zahlungsart: zahlungsart,
          datum: jetzt,
          bemerkung: 'Kassenvorgang',
        );
        // Bestand reduzieren (nur bei Kassenvorgang, nicht bei Rechnung).
        for (final p in positionen) {
          await (db.update(
            db.waren,
          )..where((w) => w.id.equals(p.wareId))).write(
            WarenCompanion(
              bestand: Value((await _ladeBestand(p.wareId)) - p.menge.round()),
              aktualisiertAm: Value(jetzt),
            ),
          );
        }
        bestandsAbgezogen = true;
      }

      return PosVorgangResult(
        rechnungId: rechnungId,
        rechnungsnummer: rechnungsnummer,
        gesamtBrutto: gesamtBrutto,
        status: sofortBezahlt ? 'bezahlt' : 'offen',
        bestandsAbgezogen: bestandsAbgezogen,
      );
    });
  }

  /// Erstellt den Kassenbericht eines Tages (Summen je Zahlart).
  Future<Tagesabschluss> erstelleTagesabschluss({DateTime? datum}) async {
    final tag = datum ?? DateTime.now();
    final start = DateTime(tag.year, tag.month, tag.day);
    final ende = addiereTage(start, 1);

    final zahlungen =
        await (db.select(db.zahlungen)..where(
              (z) =>
                  z.datum.isBiggerOrEqualValue(start) &
                  z.datum.isSmallerThanValue(ende),
            ))
            .get();

    double summeBar = 0;
    double summeKarte = 0;
    for (final z in zahlungen) {
      if (z.zahlungsart == Zahlungsart.bar.name) {
        summeBar += z.betrag;
      } else if (z.zahlungsart == Zahlungsart.karte.name) {
        summeKarte += z.betrag;
      }
    }

    // Rechnungen des Tages, die NICHT über die Kasse bezahlt wurden.
    final rechnungen =
        await (db.select(db.rechnungen)..where(
              (r) =>
                  r.datum.isBiggerOrEqualValue(start) &
                  r.datum.isSmallerThanValue(ende) &
                  r.status.equals('offen'),
            ))
            .get();
    final summeRechnung = rechnungen.fold<double>(
      0,
      (sum, r) => sum + r.betragBrutto,
    );

    return Tagesabschluss(
      datum: start,
      anzahlVorgaenge: zahlungen.length + rechnungen.length,
      summeBar: summeBar,
      summeKarte: summeKarte,
      summeRechnung: summeRechnung,
    );
  }

  Future<int> _ladeBestand(int warenId) async {
    final w = await (db.select(
      db.waren,
    )..where((w) => w.id.equals(warenId))).getSingle();
    return w.bestand;
  }
}

/// Provider für [`PosRepository`].
@riverpod
PosRepository posRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final rechnungen = ref.watch(rechnungenRepositoryProvider);
  final zahlungen = ref.watch(zahlungServiceProvider);
  return PosRepository(db, rechnungen, zahlungen);
}
