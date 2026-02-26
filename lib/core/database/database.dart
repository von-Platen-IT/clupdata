import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/bemerkung_table.dart';
import 'tables/stammdaten_table.dart';
import 'tables/preis_table.dart';
import 'tables/leistung_table.dart';
import 'tables/mitglied_table.dart';

part 'database.g.dart';

/// The main entry point for the Drift SQLite database.
///
/// [AppDatabase] coordinates all tables and manages the background connection.
@DriftDatabase(tables: [
  Bemerkung,
  Stammdaten,
  Preis,
  Leistung,
  Mitglieds
])
class AppDatabase extends _$AppDatabase {
  /// Initializes the database with a lazily opened connection.
  AppDatabase() : super(_openConnection());

  /// The schema version. Increment this when making changes to any [Table] design.
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      // Re-create all tables on version 4 since we changed the whole schema.
      // NOTE: In an actual production app with existing data, this would need complex data-migration mappings
      if (from < 4) {
        for (final table in allTables) {
          await migrator.deleteTable(table.actualTableName);
          await migrator.createTable(table);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the SQLite database connection lazily on a background thread.
///
/// It determines the correct `ApplicationDocumentsDirectory` for the current
/// platform (Windows/macOS/Linux) and creates `clup_data.sqlite` there.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'clup_data.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
