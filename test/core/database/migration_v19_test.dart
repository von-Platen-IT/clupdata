import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Testet die Migrationsschritte von Schema v18 → v19 direkt auf SQL-Ebene.
///
/// Simuliert den v18-Zustand (Tabelle `beitrag` ohne `faellig_am`) und prüft,
/// dass die Migration die Spalte anlegt und bestehende Zeilen korrekt befüllt.
/// Die Migration ist idempotent (mehrfacher Lauf ohne Fehler).
void main() {
  setUpAll(() {
    // Linux-Systeme haben oft nur libsqlite3.so.0 (ohne Dev-Link .so).
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
  });

  tearDown(() {
    db.dispose();
  });

  void fuehreMigrationAus() {
    // Spalte anlegen (idempotent – Fehler bei vorhandener Spalte ignorieren).
    try {
      db.execute(
        'ALTER TABLE beitrag ADD COLUMN faellig_am INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {/* Spalte existiert bereits */}
    db.execute(
      'UPDATE beitrag SET faellig_am = kontiert_am + 1209600 '
      'WHERE faellig_am = 0 OR faellig_am IS NULL',
    );
  }

  test('legt faellig_am an und befüllt bestehende Zeilen (14 Tage)', () {
    // v18-Zustand simulieren: beitrag ohne faellig_am.
    db.execute(
      'CREATE TABLE beitrag (id INTEGER PRIMARY KEY, kontiert_am INTEGER NOT NULL)',
    );
    // 2026-06-01 00:00:00 UTC als Unix-Sekunden.
    db.execute('INSERT INTO beitrag (kontiert_am) VALUES (1780272000)');

    fuehreMigrationAus();

    final rows = db.select('SELECT faellig_am FROM beitrag');
    final faellig = rows.first['faellig_am'] as int;
    // 14 Tage = 1.209.600 Sekunden.
    expect(faellig, 1780272000 + 1209600);
  });

  test('Migration ist idempotent (mehrfacher Lauf ohne Fehler)', () {
    db.execute(
      'CREATE TABLE beitrag (id INTEGER PRIMARY KEY, kontiert_am INTEGER NOT NULL)',
    );
    db.execute('INSERT INTO beitrag (kontiert_am) VALUES (1780272000)');

    fuehreMigrationAus();
    fuehreMigrationAus(); // zweiter Lauf darf nicht scheitern

    final rows = db.select('SELECT faellig_am FROM beitrag');
    expect(rows.first['faellig_am'], 1780272000 + 1209600);
  });

  test('bereits befüllte Zeilen bleiben unverändert', () {
    db.execute(
      'CREATE TABLE beitrag (id INTEGER PRIMARY KEY, kontiert_am INTEGER NOT NULL)',
    );
    db.execute('INSERT INTO beitrag (kontiert_am) VALUES (1780272000)');

    fuehreMigrationAus();
    // Manuelles Update auf einen anderen Wert – Migration darf nicht
    // überschreiben (WHERE faellig_am = 0 greift nicht).
    db.execute('UPDATE beitrag SET faellig_am = 42');
    fuehreMigrationAus();

    final rows = db.select('SELECT faellig_am FROM beitrag');
    expect(rows.first['faellig_am'], 42);
  });
}
