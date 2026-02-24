import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/database/database.dart';

part 'master_data_repository.g.dart';

@riverpod
class TrainersRepository extends _$TrainersRepository {
  @override
  Stream<List<Trainer>> build() {
    final database = ref.watch(appDatabaseProvider);
    return database.select(database.trainers).watch().map((rows) => rows.map((row) => Trainer(
      id: row.id,
      name: row.name,
      isActive: row.isActive,
    )).toList());
  }

  Future<void> addTrainer(String name) async {
    final database = ref.read(appDatabaseProvider);
    await database.into(database.trainers).insert(db.TrainersCompanion.insert(name: name));
  }

  Future<void> updateTrainer(Trainer trainer) async {
    final database = ref.read(appDatabaseProvider);
    await database.update(database.trainers).replace(db.Trainer(
      id: trainer.id,
      name: trainer.name,
      isActive: trainer.isActive,
    ));
  }

  Future<void> deleteTrainer(int id) async {
    final database = ref.read(appDatabaseProvider);
    await (database.delete(database.trainers)..where((t) => t.id.equals(id))).go();
  }
}

@riverpod
class CourseTypesRepository extends _$CourseTypesRepository {
  @override
  Stream<List<CourseType>> build() {
    final database = ref.watch(appDatabaseProvider);
    return database.select(database.courseTypes).watch().map((rows) => rows.map((row) => CourseType(
      id: row.id,
      name: row.name,
    )).toList());
  }

  Future<void> addCourseType(String name) async {
    final database = ref.read(appDatabaseProvider);
    await database.into(database.courseTypes).insert(db.CourseTypesCompanion.insert(name: name));
  }

  Future<void> updateCourseType(CourseType courseType) async {
    final database = ref.read(appDatabaseProvider);
    await database.update(database.courseTypes).replace(db.CourseType(
      id: courseType.id,
      name: courseType.name,
    ));
  }

  Future<void> deleteCourseType(int id) async {
    final database = ref.read(appDatabaseProvider);
    await (database.delete(database.courseTypes)..where((t) => t.id.equals(id))).go();
  }
}

@riverpod
class LocationsRepository extends _$LocationsRepository {
  @override
  Stream<List<Location>> build() {
    final database = ref.watch(appDatabaseProvider);
    return database.select(database.locations).watch().map((rows) => rows.map((row) => Location(
      id: row.id,
      name: row.name,
    )).toList());
  }

  Future<void> addLocation(String name) async {
    final database = ref.read(appDatabaseProvider);
    await database.into(database.locations).insert(db.LocationsCompanion.insert(name: name));
  }

  Future<void> updateLocation(Location location) async {
    final database = ref.read(appDatabaseProvider);
    await database.update(database.locations).replace(db.Location(
      id: location.id,
      name: location.name,
    ));
  }

  Future<void> deleteLocation(int id) async {
    final database = ref.read(appDatabaseProvider);
    await (database.delete(database.locations)..where((l) => l.id.equals(id))).go();
  }
}
