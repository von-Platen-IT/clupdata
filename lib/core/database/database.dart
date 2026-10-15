import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../utils/sqlite_loader.dart';
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
import 'tables/rechnung_status_verlauf_table.dart';
import 'tables/zahlung_table.dart';
import 'tables/mahnung_table.dart';
import 'tables/kurs_table.dart';
import 'tables/kursplan_table.dart';
import 'tables/kursplan_termin_table.dart';

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
    RechnungStatusVerlaeufe,
    Zahlungen,
    Mahnungen,
    Kurs,
    Kursplan,
    KursplanTermine,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Initializes the database with a lazily opened connection.
  AppDatabase() : super(_openConnection());

  /// Creates a database on a custom [QueryExecutor].
  ///
  /// Used by unit tests to run against an in-memory database
  /// (`NativeDatabase.memory()`).
  AppDatabase.forTesting(super.e);

  /// Gibt den Pfad der Datenbankdatei zurück.
  static String get dbFilePath => _resolveDbPath();

  /// The schema version. Increment this when making changes to any [Table] design.
  @override
  int get schemaVersion => 19;

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
      } else if (from == 17) {
        // v18: Kursplan-Tabellen (kurs, kursplan, kursplan_termin)
        await migrator.createTable(kurs);
        await migrator.createTable(kursplan);
        await migrator.createTable(kursplanTermine);
        if (to > 18) {
          await _migrateToV19(migrator);
        }
      } else if (from == 18) {
        // v19: Billing-Datenmodell (Zahlungen, Mahnungen, Rechnungs-Status-Verlauf)
        await _migrateToV19(migrator);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Migration auf Schema v19: Billing-Datenmodell.
  ///
  /// - Neue Tabellen `zahlung`, `mahnung`, `rechnung_status_verlauf`
  /// - Neue Spalte `beitrag.faellig_am` (Default: `kontiert_am + 14 Tage`)
  ///
  /// Rein additiv, forward-only (keine Datenverluste). **Idempotent**:
  /// Die Migration kann bei einem vorherigen Fehlschlag teilgelaufen sein,
  /// jeder Schritt ist deshalb einzeln abgesichert.
  Future<void> _migrateToV19(Migrator migrator) async {
    // Tabellen nur anlegen, wenn noch nicht vorhanden (idempotent).
    try {
      await migrator.createTable(zahlungen);
    } catch (_) {/* bereits vorhanden */}
    try {
      await migrator.createTable(mahnungen);
    } catch (_) {/* bereits vorhanden */}
    try {
      await migrator.createTable(rechnungStatusVerlaeufe);
    } catch (_) {/* bereits vorhanden */}

    // Spalte faellig_am: SQLite erlaubt kein ALTER ADD COLUMN NOT NULL ohne
    // Default – daher mit Default 0 anlegen und anschließend befüllen.
    // Drift speichert DateTime als Unix-Timestamp in Sekunden.
    try {
      await customStatement(
        'ALTER TABLE beitrag ADD COLUMN faellig_am INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {/* Spalte existiert bereits */}
    // Bestehende Beiträge: Fälligkeit = kontiert_am + 14 Tage.
    await customStatement(
      'UPDATE beitrag SET faellig_am = kontiert_am + 1209600 '
      'WHERE faellig_am = 0 OR faellig_am IS NULL',
    );
  }
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
    final pfad = _resolveDbPath();
    debugPrint('[sqlite3] Öffne Datenbank: $pfad');
    return NativeDatabase.createInBackground(
      File(pfad),
      // WICHTIG: Das Library-Override muss auch im Hintergrund-Isolate
      // ausgeführt werden – dort greift das Override des Haupt-Isolates NICHT.
      isolateSetup: configureSqlite,
    );
  });
}
