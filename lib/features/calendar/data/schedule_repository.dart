import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

part 'schedule_repository.g.dart';

/// A repository that manages data access for recurring weekly course schedules.
///
/// It wraps all Drift database operations for the `CourseSchedules` table and
/// keeps the UI layer free of any ORM-specific code.
class ScheduleRepository {
  final AppDatabase _db;

  /// Creates a [ScheduleRepository] with a required database connection.
  ScheduleRepository(this._db);

  /// Returns a real-time reactive stream of all course schedule entries.
  ///
  /// The UI can watch this to automatically rebuild when courses are added or removed.
  Stream<List<CourseSchedule>> watchAllSchedules() {
    return (_db.select(_db.courseSchedules)
          ..orderBy([(c) => OrderingTerm.asc(c.weekday), (c) => OrderingTerm.asc(c.startHour), (c) => OrderingTerm.asc(c.startMinute)]))
        .watch();
  }

  /// Inserts a new course [entry] into the database.
  ///
  /// Returns the auto-generated [id] of the inserted course.
  Future<int> addCourse(CourseSchedulesCompanion entry) {
    return _db.into(_db.courseSchedules).insert(entry);
  }

  /// Permanently deletes a course entry by its [id].
  Future<int> deleteCourse(int id) {
    return (_db.delete(_db.courseSchedules)..where((c) => c.id.equals(id))).go();
  }

  /// Updates an existing course schedule entry.
  ///
  /// Returns `true` if a row was successfully updated.
  Future<bool> updateCourse(CourseSchedule course) {
    return _db.update(_db.courseSchedules).replace(course);
  }
}

/// Riverpod provider for the [ScheduleRepository].
///
/// Supplies the repository with a shared [AppDatabase] instance.
@riverpod
ScheduleRepository scheduleRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ScheduleRepository(db);
}

/// A global stream provider emitting the current list of all course schedules.
///
/// Prefer this over calling the repository directly from the UI.
final scheduleStreamProvider = StreamProvider<List<CourseSchedule>>((ref) {
  return ref.watch(scheduleRepositoryProvider).watchAllSchedules();
});
