import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Defines the structure for the `Members` table in the local SQLite database.
///
/// This table holds all core information about the boxing club members.
class Members extends Table {
  /// The unique identifier for a member.
  IntColumn get id => integer().autoIncrement()();
  /// The member's first name.
  TextColumn get firstName => text()();
  /// The member's last name.
  TextColumn get lastName => text()();
  /// The date the member joined the club.
  DateTimeColumn get joinDate => dateTime()();
  /// Indicates if the member is currently active (e.g. paying dues, allowed to train).
  BoolColumn get isActive => boolean()();
}

/// Defines the structure for the `Contracts` table.
///
/// This table links [Members] to their specific membership plans (e.g., 6-month, 12-month).
class Contracts extends Table {
  /// The unique identifier for a contract.
  IntColumn get id => integer().autoIncrement()();
  /// Foreign key linking to the [Members] table.
  IntColumn get memberId => integer().references(Members, #id)();
  /// The name of the contract or plan (e.g., "Full Membership", "Student Plan").
  TextColumn get planName => text()();
  /// The recurring monthly fee for this contract.
  RealColumn get monthlyFee => real()();
  /// The date when this contract started.
  DateTimeColumn get startDate => dateTime()();
}

/// Defines the structure for the `Sales` (Point of Sale) table.
///
/// This table records one-time purchases like drinks, equipment, or guest passes.
class Sales extends Table {
  /// The unique identifier for a sale record.
  IntColumn get id => integer().autoIncrement()();
  /// An optional foreign key linking to a club member. Can be null for anonymous guest sales.
  IntColumn get memberId => integer().nullable().references(Members, #id)();
  /// The name/description of the sold item (e.g., "Water Bottle", "Hand wraps").
  TextColumn get itemName => text()();
  /// The final price charged for this individual sale.
  RealColumn get price => real()();
  /// The exact date and time the sale was processed.
  DateTimeColumn get saleDate => dateTime()();
}

/// Defines the structure for the `CourseSchedules` table.
///
/// This table stores recurring weekly course entries for the club schedule,
/// displayed in the calendar timetable view.
class CourseSchedules extends Table {
  /// The unique identifier for a course entry.
  IntColumn get id => integer().autoIncrement()();
  /// The name of the course (e.g., "Boxen Anfänger").
  TextColumn get title => text()();
  /// The name of the trainer responsible for this course.
  TextColumn get trainer => text()();
  /// The weekday as an integer (1 = Monday, 7 = Sunday).
  IntColumn get weekday => integer()();
  /// The start hour of the course (0–23).
  IntColumn get startHour => integer()();
  /// The start minute of the course (0, 15, 30, 45).
  IntColumn get startMinute => integer()();
  /// Duration of the course in minutes (e.g., 60, 90).
  IntColumn get durationMinutes => integer()();
  /// Room or location of the course (e.g., "Ring 1").
  TextColumn get location => text().withDefault(const Constant(''))();
}

/// The main entry point for the Drift SQLite database.
///
/// [AppDatabase] coordinates all tables (`Members`, `Contracts`, `Sales`) and
/// manages the background connection to the local SQLite file.
/// Defines the structure for the `Trainers` table.
class Trainers extends Table {
  /// The unique identifier for a trainer.
  IntColumn get id => integer().autoIncrement()();
  /// The name of the trainer.
  TextColumn get name => text()();
  /// Indicates if the trainer is active.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Defines the structure for the `CourseTypes` table.
class CourseTypes extends Table {
  /// The unique identifier for a course type.
  IntColumn get id => integer().autoIncrement()();
  /// The name of the course type.
  TextColumn get name => text()();
}

/// Defines the structure for the `Locations` table.
class Locations extends Table {
  /// The unique identifier for a location.
  IntColumn get id => integer().autoIncrement()();
  /// The name of the location.
  TextColumn get name => text()();
}

/// The main entry point for the Drift SQLite database.
///
/// [AppDatabase] coordinates all tables and manages the background connection.
@DriftDatabase(tables: [
  Members,
  Contracts,
  Sales,
  CourseSchedules,
  Trainers,
  CourseTypes,
  Locations
])
class AppDatabase extends _$AppDatabase {
  /// Initializes the database with a lazily opened connection.
  AppDatabase() : super(_openConnection());

  /// The schema version. Increment this when making changes to any [Table] design.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Add the CourseSchedules table introduced in version 2.
        await migrator.createTable(courseSchedules);
      }
      if (from < 3) {
        // Add master data tables introduced in version 3.
        await migrator.createTable(trainers);
        await migrator.createTable(courseTypes);
        await migrator.createTable(locations);
      }
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
