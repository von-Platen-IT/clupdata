import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show innerJoin, leftOuterJoin;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/rechnungsnummer_generator.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../billing/services/faelligkeit_service.dart';
import '../domain/models/abrechnung_ergebnis.dart';
import '../domain/models/abrechnungslauf_state.dart';
import '../domain/models/vorschau_zeile.dart';
import '../domain/models/zeitraum_typ.dart';

part 'abrechnung_service.g.dart';

/// Join-Zeile: Mitglied mit Vertrag (Leistung) und optionalem Einzelpreis.
typedef _VertragZeile = ({
  Mitglied mitglied,
  LeistungItem leistung,
  PreisItem? mitgliedPreis,
});

/// Service für die Beitrags-Rechnungsstellung (Abrechnungslauf).
///
/// Migriert aus dem früheren `AbrechnungService` des
/// `rechnungserstellung`-Features – die bewährte Periodenlogik bleibt
/// unverändert (Idempotenz-Schlüssel `mitgliedId + abrechnungsZeitraum`,
/// Preis-Snapshot, Savepoint-Transaktionen) und wird um die Fälligkeits-
/// berechnung erweitert.
///
/// **Datenintegrität**:
/// - Die gesamte Erstellung läuft in einer DB-Transaktion.
///   Einzelfehler werden protokolliert (Zeile wird via Savepoint zurückgerollt),
///   unerwartete Fehler führen zum vollständigen Rollback.
/// - Duplikat-Schlüssel `mitgliedId + abrechnungsZeitraum` macht die
///   Erstellung idempotent.
/// - Preis-Snapshot (Kopie in `preis`), niemals Live-Referenz.
/// - Initialer `beitrag_status_verlauf`-Eintrag mit verpflichtender Bemerkung.
class AbrechnungService {
  AbrechnungService(this.db, this._faelligkeit) {
    rechnungsnummerGenerator = RechnungsnummerGenerator(db);
  }

  final AppDatabase db;
  final FaelligkeitService _faelligkeit;
  late final RechnungsnummerGenerator rechnungsnummerGenerator;

  /// Erzeugt die Abrechnungs-Vorschau für den gegebenen [state].
  ///
  /// Berücksichtigt Empfängerkreis, Abrechnungsrhythmus (aus `leistung.laufzeit`)
  /// und markiert bereits abgerechnete Perioden ([VorschauZeile.bereitsAbgerechnet]).
  Future<List<VorschauZeile>> ladeVorschau(AbrechnungslaufState state) async {
    final von = _vonAusState(state);
    final bis = _bisAusState(state);
    final faelligAm = _faelligkeit.berechneFaelligkeitMitZiel(
      DateTime.now(),
      state.zahlungszielTage,
    );

    // 1. Mitglieder mit Vertrag + optionale Preise laden
    final query = db.select(db.mitglieds).join([
      innerJoin(db.leistung, db.leistung.id.equalsExp(db.mitglieds.leistungId)),
      leftOuterJoin(db.preis, db.preis.id.equalsExp(db.mitglieds.preisId)),
    ]);

    if (state.mitgliedIds.isNotEmpty) {
      query.where(db.mitglieds.id.isIn(state.mitgliedIds));
    }
    if (state.leistungIds.isNotEmpty) {
      query.where(db.leistung.id.isIn(state.leistungIds));
    }
    if (state.nurAktiveVertraege) {
      // Unbefristete Verträge (NULL) gelten als aktiv.
      query.where(
        db.mitglieds.vertragLaufzeitBis.isNull() |
            db.mitglieds.vertragLaufzeitBis.isBiggerOrEqualValue(DateTime.now()),
      );
    }

    final rows = await query.get();
    if (rows.isEmpty) return [];

    final List<_VertragZeile> mitglieder = rows
        .map(
          (row) => (
            mitglied: row.readTable(db.mitglieds),
            leistung: row.readTable(db.leistung),
            mitgliedPreis: row.readTableOrNull(db.preis),
          ),
        )
        .toList();

    // 2. Nur-Mitglieder-ohne-offene-Filter
    var gefiltert = mitglieder;
    if (state.nurOhneOffene) {
      final gesperrt = await _loadMitgliederMitOffenenBeitraegen();
      gefiltert = mitglieder
          .where((m) => !gesperrt.contains(m.mitglied.id))
          .toList();
    }

    // 3. Leistungspreise (Fallback) cachen
    final leistungsPreise = await _loadLeistungsPreise(
      gefiltert.map((m) => m.leistung.id).toSet(),
    );

    // 4. Perioden je Leistung (Rhythmus aus leistung.laufzeit)
    final periodenCache = <String, List<DateTime>>{};
    var minPeriodenStart = bis;
    var maxPeriodenEnde = von;
    for (final m in gefiltert) {
      final key = m.leistung.laufzeit;
      final perioden = periodenCache.putIfAbsent(
        key,
        () => _periodenFuer(key, von, bis),
      );
      for (final p in perioden) {
        if (p.isBefore(minPeriodenStart)) minPeriodenStart = p;
        if (p.isAfter(maxPeriodenEnde)) maxPeriodenEnde = p;
      }
    }

    // 5. Bereits abgerechnete Perioden laden (halboffene Abfrage)
    final existierende = await _loadExistierendeSchluessel(
      minPeriodenStart,
      DateTime(maxPeriodenEnde.year, maxPeriodenEnde.month + 1, 1),
    );

    // 6. Einmalig-Leistungen: global abgerechnet?
    final einmaligLeistungIds = gefiltert
        .where((m) => m.leistung.laufzeit == 'einmalig')
        .map((m) => m.leistung.id)
        .toSet();
    final einmaligAbgerechnet = einmaligLeistungIds.isEmpty
        ? <String>{}
        : await _loadEinmaligAbgerechnet(
            gefiltert.map((m) => m.mitglied.id).toSet(),
            einmaligLeistungIds,
          );

    // 7. Vorschau-Zeilen erzeugen
    final zeilen = <VorschauZeile>[];
    for (final m in gefiltert) {
      final perioden = periodenCache[m.leistung.laufzeit]!;
      final betrag =
          m.mitgliedPreis?.bruttopreis ?? leistungsPreise[m.leistung.id] ?? 0.0;
      final hinweis = m.mitgliedPreis != null
          ? 'abweichender Einzelpreis'
          : betrag == 0
          ? 'kein Preis hinterlegt – Betrag manuell eintragen'
          : null;

      for (final periode in perioden) {
        final schluessel = '${m.mitglied.id}_${periode.year}-${periode.month}';
        final bereits = m.leistung.laufzeit == 'einmalig'
            ? einmaligAbgerechnet.contains('${m.mitglied.id}_${m.leistung.id}')
            : existierende.contains(schluessel);

        zeilen.add(
          VorschauZeile(
            mitgliedId: m.mitglied.id,
            mitgliedName: '${m.mitglied.name}, ${m.mitglied.vorname}',
            leistungId: m.leistung.id,
            leistungName: m.leistung.name,
            abrechnungsZeitraum: periode,
            betrag: betrag,
            faelligAm: faelligAm,
            inkludiert: !bereits,
            bereitsAbgerechnet: bereits,
            hinweis: bereits ? 'bereits abgerechnet' : hinweis,
          ),
        );
      }
    }

    return zeilen;
  }

  /// Erstellt die Beiträge der ausgewählten [zeilen] atomar.
  ///
  /// Zeilen ohne [VorschauZeile.kannErstelltWerden] werden übersprungen.
  /// Einzelfehler werden protokolliert, ohne die übrigen Zeilen zu verwerfen.
  Future<AbrechnungErgebnis> fuehreAus(
    List<VorschauZeile> zeilen,
    AbrechnungslaufState state,
  ) async {
    final kontierungDate = DateTime.now();
    final bemerkung = (state.bemerkung?.isNotEmpty ?? false)
        ? state.bemerkung!
        : 'Beitrag durch Abrechnungslauf erstellt';

    // Frische Duplikat-Prüfung: Ausführung ist idempotent.
    DateTime? minPeriode;
    DateTime? maxPeriode;
    for (final z in zeilen) {
      final p = z.abrechnungsZeitraum;
      if (minPeriode == null || p.isBefore(minPeriode)) minPeriode = p;
      if (maxPeriode == null || p.isAfter(maxPeriode)) maxPeriode = p;
    }
    final existierende = maxPeriode == null
        ? <String>{}
        : await _loadExistierendeSchluessel(
            minPeriode!,
            DateTime(maxPeriode.year, maxPeriode.month + 1, 1),
          );

    return db.transaction(() async {
      final erstelltNummern = <String>[];
      final errors = <String>[];
      var successCount = 0;
      var skippedCount = 0;
      var gesamtBetrag = 0.0;

      for (final zeile in zeilen) {
        if (!zeile.kannErstelltWerden) {
          skippedCount++;
          continue;
        }
        final schluessel =
            '${zeile.mitgliedId}_${zeile.abrechnungsZeitraum.year}'
            '-${zeile.abrechnungsZeitraum.month}';
        if (existierende.contains(schluessel)) {
          skippedCount++;
          continue;
        }

        try {
          String? rechnungsnummer;
          int? beitragId;

          // Savepoint je Zeile: bei Fehler wird nur diese Zeile zurückgerollt.
          await db.transaction(() async {
            // Preis-Snapshot (Kopie, keine Live-Referenz)
            final preisId = await db
                .into(db.preis)
                .insert(PreisCompanion.insert(bruttopreis: zeile.betrag));

            rechnungsnummer = await rechnungsnummerGenerator.generateForBeitrag();

            beitragId = await db
                .into(db.beitraege)
                .insert(
                  BeitraegeCompanion.insert(
                    mitgliedId: zeile.mitgliedId,
                    leistungId: zeile.leistungId,
                    preisId: drift.Value(preisId),
                    rechnungsnummer: rechnungsnummer!,
                    status: state.zielStatus,
                    kontiertAm: kontierungDate,
                    abrechnungsZeitraum: drift.Value(zeile.abrechnungsZeitraum),
                    faelligAm: zeile.faelligAm,
                    statusDatum: kontierungDate,
                  ),
                );

            // Initialer Status-Verlauf (Bemerkung ist Pflicht!)
            await db
                .into(db.beitragStatusVerlauf)
                .insert(
                  BeitragStatusVerlaufCompanion.insert(
                    beitragId: beitragId!,
                    status: state.zielStatus,
                    geaendertAm: DateTime.now(),
                    bemerkung: bemerkung,
                  ),
                );
          });

          existierende.add(schluessel);
          erstelltNummern.add(rechnungsnummer!);
          gesamtBetrag += zeile.betrag;
          successCount++;
        } catch (e) {
          // Personenbezogene Daten nur als Name für die UI, nicht in Logs.
          errors.add('${zeile.mitgliedName} (ID ${zeile.mitgliedId}): $e');
        }
      }

      return AbrechnungErgebnis(
        erstelltAnzahl: successCount,
        uebersprungenAnzahl: skippedCount,
        gesamtBetrag: gesamtBetrag,
        fehler: errors,
        erstellteNummern: erstelltNummern,
      );
    });
  }

  // ── Zeitraum & Periodenbildung ─────────────────────────────────────────

  /// Start des Abrechnungszeitraums (Monatsanfang, inklusiv).
  DateTime _vonAusState(AbrechnungslaufState s) {
    switch (s.zeitraumTyp) {
      case ZeitraumTyp.monat:
        return DateTime(s.jahr, s.monat, 1);
      case ZeitraumTyp.quartal:
        return DateTime(s.jahr, (s.quartal - 1) * 3 + 1, 1);
      case ZeitraumTyp.jahr:
        return DateTime(s.jahr, 1, 1);
      case ZeitraumTyp.periode:
        return DateTime(s.von!.year, s.von!.month, 1);
    }
  }

  /// Ende des Abrechnungszeitraums (Monatsanfang, exklusiv).
  DateTime _bisAusState(AbrechnungslaufState s) {
    switch (s.zeitraumTyp) {
      case ZeitraumTyp.monat:
        return DateTime(s.jahr, s.monat + 1, 1);
      case ZeitraumTyp.quartal:
        return DateTime(s.jahr, (s.quartal - 1) * 3 + 4, 1);
      case ZeitraumTyp.jahr:
        return DateTime(s.jahr + 1, 1, 1);
      case ZeitraumTyp.periode:
        return DateTime(s.bis!.year, s.bis!.month + 1, 1);
    }
  }

  /// Bildet die Abrechnungsperioden (Periodenanfänge) für einen Rhythmus.
  ///
  /// - `monatlich` → jeder Monatsanfang im Zeitraum
  /// - `quartalsweise` → jeder Quartalsanfang im Zeitraum
  /// - `jaehrlich` → jeder Jahresanfang, der den Zeitraum schneidet
  /// - `einmalig` → genau eine Periode (Monatsanfang von [von])
  List<DateTime> _periodenFuer(String laufzeit, DateTime von, DateTime bis) {
    final perioden = <DateTime>[];
    switch (laufzeit) {
      case 'quartalsweise':
        var q = DateTime(von.year, ((von.month - 1) ~/ 3) * 3 + 1, 1);
        while (q.isBefore(bis)) {
          perioden.add(q);
          q = DateTime(q.year, q.month + 3, 1);
        }
      case 'jaehrlich':
        var j = DateTime(von.year, 1, 1);
        while (j.isBefore(bis)) {
          perioden.add(j);
          j = DateTime(j.year + 1, 1, 1);
        }
      case 'einmalig':
        perioden.add(DateTime(von.year, von.month, 1));
      default:
        var m = DateTime(von.year, von.month, 1);
        while (m.isBefore(bis)) {
          perioden.add(m);
          m = DateTime(m.year, m.month + 1, 1);
        }
    }
    return perioden;
  }

  // ── Datenbank-Abfragen ─────────────────────────────────────────────────

  /// Liefert alle Leistungspreise (`leistung.preis_id` → `preis.bruttopreis`).
  Future<Map<int, double>> _loadLeistungsPreise(Set<int> leistungIds) async {
    if (leistungIds.isEmpty) return {};
    final query = db.select(db.leistung).join([
      innerJoin(db.preis, db.preis.id.equalsExp(db.leistung.preisId)),
    ])..where(db.leistung.id.isIn(leistungIds));

    final result = <int, double>{};
    for (final row in await query.get()) {
      final leistung = row.readTable(db.leistung);
      result[leistung.id] = row.readTable(db.preis).bruttopreis;
    }
    return result;
  }

  /// Liefert die Duplikat-Schlüssel `mitgliedId_jahr-monat` aller bestehenden
  /// Beiträge im erweiterten Zeitraum (deckt auch Jahresperioden ab).
  Future<Set<String>> _loadExistierendeSchluessel(
    DateTime von,
    DateTime bis,
  ) async {
    // Jahresanfang von `von` mit aufnehmen (Perioden können davor liegen).
    final start = DateTime(von.year, 1, 1);
    final query = db.select(db.beitraege)
      ..where(
        (b) =>
            b.abrechnungsZeitraum.isBiggerOrEqualValue(start) &
            b.abrechnungsZeitraum.isSmallerThanValue(bis),
      );

    return (await query.get())
        .map(
          (b) =>
              '${b.mitgliedId}_${b.abrechnungsZeitraum!.year}-${b.abrechnungsZeitraum!.month}',
        )
        .toSet();
  }

  /// Liefert die Schlüssel `mitgliedId_leistungId` aller Mitglieder, die für
  /// eine `einmalig`-Leistung bereits einen Beitrag besitzen.
  Future<Set<String>> _loadEinmaligAbgerechnet(
    Set<int> mitgliedIds,
    Set<int> leistungIds,
  ) async {
    if (mitgliedIds.isEmpty || leistungIds.isEmpty) return {};
    final query = db.select(db.beitraege)
      ..where(
        (b) => b.mitgliedId.isIn(mitgliedIds) & b.leistungId.isIn(leistungIds),
      );

    return (await query.get())
        .map((b) => '${b.mitgliedId}_${b.leistungId}')
        .toSet();
  }

  /// Liefert die IDs aller Mitglieder mit `kontiert`- oder `offen`-Beiträgen.
  Future<Set<int>> _loadMitgliederMitOffenenBeitraegen() async {
    final query = db.select(db.beitraege)
      ..where(
        (b) =>
            b.status.equals('kontiert') |
            b.status.equals('offen') |
            b.status.equals('teilbezahlt'),
      );

    return (await query.get()).map((b) => b.mitgliedId).toSet();
  }
}

/// Provider für [`AbrechnungService`].
@riverpod
AbrechnungService abrechnungService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final faelligkeit = ref.watch(faelligkeitServiceProvider);
  return AbrechnungService(db, faelligkeit);
}
