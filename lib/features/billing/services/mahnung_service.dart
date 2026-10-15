import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/mahnung_repository.dart';
import '../data/offene_posten_repository.dart';
import '../domain/models/mahnung.dart' as model;
import '../domain/models/offener_posten.dart';

part 'mahnung_service.g.dart';

/// Konfiguration des Mahnwesens (Stammdaten-Defaults aus ADR-006).
class Mahnkonfiguration {
  const Mahnkonfiguration({
    this.stufe1FristTage = 7,
    this.stufe2FristTage = 14,
    this.stufe3FristTage = 21,
    this.inkassoFristTage = 30,
    this.gebuehrStufe2 = 2.0,
    this.gebuehrStufe3 = 5.0,
  });

  /// Tage nach Fälligkeit bis zur Inkasso-Empfehlung (Stufe 4).
  final int inkassoFristTage;

  /// Liefert die Frist (Tage nach Fälligkeit) für die jeweilige Stufe.
  int fristFuerStufe(int stufe) {
    return switch (stufe) {
      1 => stufe1FristTage,
      2 => stufe2FristTage,
      3 => stufe3FristTage,
      _ => inkassoFristTage,
    };
  }

  /// Tage nach Fälligkeit bis zur Zahlungserinnerung (Stufe 1).
  final int stufe1FristTage;

  /// Tage nach Fälligkeit bis zur 1. Mahnung (Stufe 2).
  final int stufe2FristTage;

  /// Tage nach Fälligkeit bis zur 2. Mahnung (Stufe 3).
  final int stufe3FristTage;

  /// Gebühr der 1. Mahnung (Stufe 2).
  final double gebuehrStufe2;

  /// Gebühr der 2. Mahnung (Stufe 3).
  final double gebuehrStufe3;

  /// Liefert die Gebühr einer Stufe (1 = keine).
  double gebuehrFuerStufe(int stufe) {
    return switch (stufe) {
      2 => gebuehrStufe2,
      3 => gebuehrStufe3,
      _ => 0,
    };
  }
}

/// Vorschlag für eine Mahnung zu einem offenen Posten.
class Mahnvorschlag {
  const Mahnvorschlag({
    required this.posten,
    required this.stufe,
    required this.gebuehr,
    required this.forderung,
  });

  final OffenerPosten posten;

  /// Nächste Mahnstufe (1–4).
  final int stufe;
  final double gebuehr;
  final double forderung;

  String get stufeLabel => switch (stufe) {
    1 => 'Zahlungserinnerung',
    2 => '1. Mahnung',
    3 => '2. Mahnung',
    4 => 'Inkasso-Empfehlung',
    _ => 'Stufe $stufe',
  };
}

/// Ergebnis eines erstellten Mahnlaufs.
class MahnlaufResult {
  const MahnlaufResult({
    required this.erstellteMahnungen,
    required this.fehler,
    required this.gesamtGebuehr,
  });

  final List<model.Mahnung> erstellteMahnungen;
  final List<String> fehler;
  final double gesamtGebuehr;
}

/// Service für das Mahnwesen (3-Stufen-Prozess, ADR-006).
///
/// Ermittelt für überfällige offene Posten die nächste Mahnstufe,
/// berechnet Gebühren und dokumentiert den Mahnlauf in
/// [`mahnung`](../../../../assets/data/structur.md).
class MahnungService {
  MahnungService(
    this.db,
    this._offenePosten,
    this._mahnungen,
    this.konfiguration,
  );

  final AppDatabase db;
  final OffenePostenRepository _offenePosten;
  final MahnungRepository _mahnungen;
  final Mahnkonfiguration konfiguration;

  /// Berechnet Mahnvorschläge für alle überfälligen offenen Posten.
  Future<List<Mahnvorschlag>> berechneMahnvorschlaege() async {
    final posten = await _offenePosten.ladeOffenePosten(nurUeberfaellig: true);
    final vorschlaege = <Mahnvorschlag>[];

    for (final p in posten) {
      final letzteStufe = switch (p.belegArt) {
        OffenerPostenArt.beitrag =>
          await _mahnungen.letzteStufeFuerBeitrag(p.belegId),
        OffenerPostenArt.rechnung =>
          await _mahnungen.letzteStufeFuerRechnung(p.belegId),
      };
      if (letzteStufe >= 4) continue; // Inkasso bereits vorgemerkt

      final naechsteStufe = letzteStufe + 1;

      // Fristen-Prüfung: Stufe nur vorschlagen, wenn die Frist erreicht ist.
      if (p.tageUeberfaellig < konfiguration.fristFuerStufe(naechsteStufe)) {
        continue;
      }

      vorschlaege.add(
        Mahnvorschlag(
          posten: p,
          stufe: naechsteStufe,
          gebuehr: konfiguration.gebuehrFuerStufe(naechsteStufe),
          forderung: p.saldo,
        ),
      );
    }
    return vorschlaege;
  }

  /// Erstellt die ausgewählten Mahnungen atomar.
  Future<MahnlaufResult> erstelleMahnlauf(List<Mahnvorschlag> auswahl) async {
    final erstellt = <model.Mahnung>[];
    final fehler = <String>[];
    var gesamtGebuehr = 0.0;

    await db.transaction(() async {
      for (final v in auswahl) {
        try {
          // Savepoint je Mahnung: bei Fehler wird Mahnung + Statuswechsel
          // gemeinsam zurückgerollt (keine halbfertigen Zustände).
          final datum = DateTime.now();
          final id = await db.transaction(() async {
            final mahnungId = await _mahnungen.insertMahnung(
              MahnungenCompanion.insert(
                beitragId: v.posten.belegArt == OffenerPostenArt.beitrag
                    ? Value(v.posten.belegId)
                    : const Value.absent(),
                rechnungId: v.posten.belegArt == OffenerPostenArt.rechnung
                    ? Value(v.posten.belegId)
                    : const Value.absent(),
                stufe: v.stufe,
                datum: datum,
                gebuehr: Value(v.gebuehr),
                forderung: v.forderung,
                bemerkung: Value(v.stufeLabel),
              ),
            );
            await _setzeMahnStatus(v, datum);
            return mahnungId;
          });

          erstellt.add(
            model.Mahnung(
              id: id,
              stufe: v.stufe,
              datum: datum,
              gebuehr: v.gebuehr,
              forderung: v.forderung,
            ),
          );
          gesamtGebuehr += v.gebuehr;
        } catch (e) {
          fehler.add('${v.posten.nummer}: $e');
        }
      }
    });

    return MahnlaufResult(
      erstellteMahnungen: erstellt,
      fehler: fehler,
      gesamtGebuehr: gesamtGebuehr,
    );
  }

  /// Setzt den Belegstatus samt Historie. Stufe 4 setzt bei Beiträgen
  /// `inkasso`, sonst `angemahnt` (Rechnungen kennen kein `inkasso`).
  Future<void> _setzeMahnStatus(Mahnvorschlag v, DateTime jetzt) async {
    final bemerkung = '${v.stufeLabel} (Forderung ${v.forderung.toStringAsFixed(2)} €)';
    if (v.posten.belegArt == OffenerPostenArt.beitrag) {
      final status = v.stufe >= 4 ? 'inkasso' : 'angemahnt';
      await (db.update(db.beitraege)
            ..where((b) => b.id.equals(v.posten.belegId)))
          .write(
        BeitraegeCompanion(
          status: Value(status),
          statusDatum: Value(jetzt),
        ),
      );
      await db
          .into(db.beitragStatusVerlauf)
          .insert(
            BeitragStatusVerlaufCompanion.insert(
              beitragId: v.posten.belegId,
              status: status,
              geaendertAm: jetzt,
              bemerkung: bemerkung,
            ),
          );
    } else {
      await (db.update(db.rechnungen)
            ..where((r) => r.id.equals(v.posten.belegId)))
          .write(const RechnungenCompanion(status: Value('angemahnt')));
      await db
          .into(db.rechnungStatusVerlaeufe)
          .insert(
            RechnungStatusVerlaeufeCompanion.insert(
              rechnungId: v.posten.belegId,
              status: 'angemahnt',
              geaendertAm: jetzt,
              bemerkung: bemerkung,
            ),
          );
    }
  }
}

/// Provider für [`MahnungService`].
@riverpod
MahnungService mahnungService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final offenePosten = ref.watch(offenePostenRepositoryProvider);
  final mahnungen = ref.watch(mahnungRepositoryProvider);
  // TODO(architekt): Mahnkonfiguration aus Stammdaten lesen.
  const konfiguration = Mahnkonfiguration();
  return MahnungService(db, offenePosten, mahnungen, konfiguration);
}
