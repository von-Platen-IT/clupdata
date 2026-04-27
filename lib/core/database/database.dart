import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../utils/uuid_helper.dart';
import 'tables/bemerkung_table.dart';
import 'tables/stammdaten_table.dart';
import 'tables/preis_table.dart';
import 'tables/leistung_table.dart';
import 'tables/mitglied_table.dart';
import 'tables/waren_table.dart';
import 'tables/beitraege_table.dart';
import 'tables/beitrag_status_verlauf_table.dart';
import 'tables/rechnung_table.dart';
import 'tables/rechnung_position_table.dart';

part 'database.g.dart';

/// The main entry point for the Drift SQLite database.
///
/// [AppDatabase] coordinates all tables and manages the background connection.
@DriftDatabase(
  tables: [
    Bemerkung,
    Stammdaten,
    Preis,
    Leistung,
    Mitglieds,
    Waren,
    Beitraege,
    BeitragStatusVerlauf,
    Rechnungen,
    RechnungPositionen,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Initializes the database with a lazily opened connection.
  AppDatabase() : super(_openConnection());

  /// Gibt den Pfad der Datenbankdatei zurück.
  static String get dbFilePath => _resolveDbPath();

  /// The schema version. Increment this when making changes to any [Table] design.
  @override
  int get schemaVersion => 17;

  /// Schreibt den WAL-Cache in die Hauptdatei (für konsistente Backups).
  Future<void> checkpoint() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      // Re-create all tables on version 5 since we changed the whole schema.
      // NOTE: In an actual production app with existing data, this would need complex data-migration mappings
      if (from < 5) {
        for (final table in allTables) {
          try {
            await migrator.deleteTable(table.actualTableName);
          } catch (_) {}
          await migrator.createTable(table);
        }
      } else if (from == 5) {
        await migrator.createTable(waren);
        if (to > 6) {
          await migrator.addColumn(mitglieds, mitglieds.geschlecht);
        }
        if (to > 7) {
          await migrator.addColumn(mitglieds, mitglieds.preisId);
        }
      } else if (from == 6) {
        await migrator.addColumn(mitglieds, mitglieds.geschlecht);
        if (to > 7) {
          await migrator.addColumn(mitglieds, mitglieds.preisId);
        }
      } else if (from == 7) {
        await migrator.addColumn(mitglieds, mitglieds.preisId);
        if (to > 8) {
          await customStatement(
            "UPDATE stammdaten SET typ = 'float' WHERE typ = 'number' AND schluessel != 'db_version'",
          );
          await customStatement(
            "UPDATE stammdaten SET typ = 'integer' WHERE typ = 'number' AND schluessel == 'db_version'",
          );
        }
      } else if (from == 8) {
        await customStatement(
          "UPDATE stammdaten SET typ = 'float' WHERE typ = 'number' AND schluessel != 'db_version'",
        );
        await customStatement(
          "UPDATE stammdaten SET typ = 'integer' WHERE typ = 'number' AND schluessel == 'db_version'",
        );
        if (to > 9) {
          await migrator.addColumn(stammdaten, stammdaten.systemPflicht);
        }
      } else if (from == 9) {
        await migrator.addColumn(stammdaten, stammdaten.systemPflicht);
        if (to > 10) {
          await migrator.createTable(beitraege);
        }
      } else if (from == 10) {
        await migrator.createTable(beitraege);
      } else if (from == 11) {
        // v12: Status history table for Beitraege
        await migrator.createTable(beitragStatusVerlauf);
      } else if (from == 12) {
        // v13: bemerkung in beitrag_status_verlauf is now NOT NULL
        // Recreate table with new schema
        await migrator.deleteTable(beitragStatusVerlauf.actualTableName);
        await migrator.createTable(beitragStatusVerlauf);
      } else if (from == 13) {
        // v14: Neue Rechnungen-Tabellen
        await migrator.createTable(rechnungen);
        await migrator.createTable(rechnungPositionen);
      } else if (from == 14) {
        // v15: Neue Spalte abrechnungsZeitraum in beitraege
        await migrator.addColumn(beitraege, beitraege.abrechnungsZeitraum);
      } else if (from == 15) {
        // v16: Tabellennamen an structur.md anpassen (Singular statt Plural)
        await customStatement('ALTER TABLE mitglieds RENAME TO mitglied');
        await customStatement('ALTER TABLE beitraege RENAME TO beitrag');
        await customStatement('ALTER TABLE rechnungen RENAME TO rechnung');
        await customStatement(
          'ALTER TABLE rechnung_positionen RENAME TO rechnung_position',
        );
      } else if (from == 16) {
        // v17: UUID-Spalten für CSV-Export/Import hinzufügen
        // Jede Tabelle erhält eine uuid TEXT UNIQUE Spalte
        // Da SQLite keine Funktions-basierten Defaults unterstützt,
        // fügen wir die Spalte als nullable hinzu und setzen UUIDs per UPDATE.
        final tables = [
          'bemerkung',
          'stammdaten',
          'preis',
          'leistung',
          'mitglied',
          'waren',
          'beitrag',
          'beitrag_status_verlauf',
          'rechnung',
          'rechnung_position',
        ];
        for (final table in tables) {
          await customStatement('ALTER TABLE $table ADD COLUMN uuid TEXT');
          // Bestehenden Zeilen eine UUID geben
          await customStatement(
            "UPDATE $table SET uuid = lower(hex(randomblob(4)) || '-' || "
            "hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)),2) || '-' || "
            "substr('89ab',abs(random())%4+1,1) || substr(hex(randomblob(2)),2) || '-' || "
            "hex(randomblob(6))) WHERE uuid IS NULL",
          );
          // NOT NULL constraint setzen (SQLite erlaubt ALTER COLUMN nicht,
          // daher via recreate für die uuid-Spalte)
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_uuid ON $table(uuid)',
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

String _resolveDbPath() {
  if (kDebugMode) {
    return 'clup_data_dev.sqlite';
  }
  final executableDir = File(Platform.resolvedExecutable).parent;
  return p.join(executableDir.path, 'clup_data.sqlite');
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return NativeDatabase.createInBackground(File(_resolveDbPath()));
  });
}
