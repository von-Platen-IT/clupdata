import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'members_repository.g.dart';

/// A repository that acts as an abstraction layer between the UI and the local [AppDatabase] for Member data.
///
/// It provides centralized CRUD (Create, Read, Update, Delete) operations specifically
/// tailored for the `Members` table, keeping Drift-specific logic away from UI controllers.
class MembersRepository {
  final AppDatabase _db;

  /// Creates a [MembersRepository] with a required database connection.
  MembersRepository(this._db);

  /// Returns a real-time reactive stream of all members.
  ///
  /// UI components subscribing to this stream will automatically rebuild
  /// whenever a member is added, updated, or removed in the database.
  Stream<List<Member>> watchAllMembers() {
    return _db.select(_db.members).watch();
  }

  /// Fetches all members from the database exactly once.
  Future<List<Member>> getAllMembers() {
    return _db.select(_db.members).get();
  }

  /// Inserts a new [member] into the database.
  ///
  /// Returns the auto-generated [id] of the newly inserted member.
  Future<int> addMember(MembersCompanion member) {
    return _db.into(_db.members).insert(member);
  }

  /// Updates an existing [member] in the database.
  ///
  /// Replaces the whole row with the provided [Member] object based on its primary key.
  Future<bool> updateMember(Member member) {
    return _db.update(_db.members).replace(member);
  }

  /// Soft-deletes a member by setting their `isActive` flag to `false`.
  ///
  /// The member is not permanently deleted to preserve historical data
  /// (e.g., past contracts and sales).
  Future<int> deactivateMember(int id) {
    return (_db.update(_db.members)..where((m) => m.id.equals(id)))
        .write(const MembersCompanion(isActive: Value(false)));
  }
}

/// Riverpod provider for the [MembersRepository].
///
/// Ensures only a single instance of the repository exists and provides
/// it with the required [appDatabaseProvider] instance.
@riverpod
MembersRepository membersRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return MembersRepository(db);
}
