import 'dart:ffi';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/schnellerfassung/data/vorlage_repository.dart';
import 'package:clupdata/features/schnellerfassung/domain/models/schnellerfassung_felder.dart';

void main() {
  late AppDatabase db;
  late VorlageRepository repo;

  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VorlageRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('saveVorlage / loadVorlagen', () {
    test('speichert und lädt eine Vorlage (JSON-Roundtrip)', () async {
      final felder = SchnellerfassungFelder(
        anrede: 'Frau',
        name: 'Muster',
        vorname: 'Maria',
        plz: '12345',
        ort: 'Musterstadt',
        leistungId: 7,
      );

      await repo.saveVorlage('Erwachsene Boxen', felder);

      final vorlagen = await repo.loadVorlagen();
      expect(vorlagen, hasLength(1));
      expect(vorlagen.single.name, 'Erwachsene Boxen');
      expect(vorlagen.single.schluessel, 'vorlage_mitglied_erwachsene_boxen');
      expect(vorlagen.single.felder['name'], 'Muster');
      expect(vorlagen.single.felder['leistungId'], '7');
    });

    test('gleicher Name überschreibt die Vorlage', () async {
      await repo.saveVorlage('Standard', const SchnellerfassungFelder());
      await repo.saveVorlage(
        'Standard',
        const SchnellerfassungFelder(name: 'Neu'),
      );

      final vorlagen = await repo.loadVorlagen();
      expect(vorlagen, hasLength(1));
      expect(vorlagen.single.felder['name'], 'Neu');
    });

    test('liefert mehrere Vorlagen sortiert nach Name', () async {
      await repo.saveVorlage('Zweite', const SchnellerfassungFelder());
      await repo.saveVorlage('Erste', const SchnellerfassungFelder());

      final vorlagen = await repo.loadVorlagen();
      expect(vorlagen.map((v) => v.name), ['Erste', 'Zweite']);
    });

    test('ignoriert defekte JSON-Einträge', () async {
      // Defekten Eintrag direkt anlegen (simuliert alte/korrupte Daten).
      await db
          .into(db.stammdaten)
          .insert(
            StammdatenCompanion.insert(
              schluessel: 'vorlage_mitglied_defekt',
              wert: const Value('kein-json'),
              typ: 'string',
              kategorie: 'programm',
              bezeichnung: 'Defekt',
            ),
          );

      final vorlagen = await repo.loadVorlagen();
      expect(vorlagen, isEmpty);
    });

    test('findet nur Vorlagen mit korrektem Präfix', () async {
      await repo.saveVorlage('Test', const SchnellerfassungFelder());
      await db
          .into(db.stammdaten)
          .insert(
            StammdatenCompanion.insert(
              schluessel: 'anderer_schluessel',
              wert: const Value('{}'),
              typ: 'string',
              kategorie: 'programm',
              bezeichnung: 'Keine Vorlage',
            ),
          );

      final vorlagen = await repo.loadVorlagen();
      expect(vorlagen, hasLength(1));
    });
  });

  group('deleteVorlage', () {
    test('löscht eine gespeicherte Vorlage', () async {
      await repo.saveVorlage('Zum Loeschen', const SchnellerfassungFelder());
      final vorlagen = await repo.loadVorlagen();

      await repo.deleteVorlage(vorlagen.single.schluessel);

      expect(await repo.loadVorlagen(), isEmpty);
    });
  });

  group('Slug-Bildung', () {
    test('Sonderzeichen werden ersetzt', () async {
      await repo.saveVorlage(
        'Kinder & Jugend!',
        const SchnellerfassungFelder(),
      );
      final vorlagen = await repo.loadVorlagen();

      expect(vorlagen.single.schluessel, 'vorlage_mitglied_kinder_jugend');
    });
  });
}
