import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/bemerkung_table.dart';
import 'tables/stammdaten_table.dart';
import 'tables/preis_table.dart';
import 'tables/leistung_table.dart';
import 'tables/mitglied_table.dart';
import 'tables/waren_table.dart';
import 'tables/beitraege_table.dart';
import 'tables/beitrag_status_verlauf_table.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Initializes the database with a lazily opened connection.
  AppDatabase() : super(_openConnection());

  /// The schema version. Increment this when making changes to any [Table] design.
  @override
  int get schemaVersion => 13;

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
          await migrator.issueCustomQuery(
            "UPDATE stammdaten SET typ = 'float' WHERE typ = 'number' AND schluessel != 'db_version'",
          );
          await migrator.issueCustomQuery(
            "UPDATE stammdaten SET typ = 'integer' WHERE typ = 'number' AND schluessel == 'db_version'",
          );
        }
      } else if (from == 8) {
        await migrator.issueCustomQuery(
          "UPDATE stammdaten SET typ = 'float' WHERE typ = 'number' AND schluessel != 'db_version'",
        );
        await migrator.issueCustomQuery(
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
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    File file;
    if (kDebugMode) {
      // In der Entwicklung (flutter run) wird der build-Ordner oft gelöscht.
      // Wir speichern die DB für die Entwicklung stattdessen direkt im Projektordner.
      file = File('clup_data_dev.sqlite');
    } else {
      // Im produktiven Einsatz (Release-Build) soll die App portabel (z.B. USB-Stick) sein,
      // daher speichern wir die DB direkt neben der ausführenden Datei (.exe / ELF-Binary).
      final executableDir = File(Platform.resolvedExecutable).parent;
      file = File(p.join(executableDir.path, 'clup_data.sqlite'));
    }

    return NativeDatabase.createInBackground(file);
  });
}
