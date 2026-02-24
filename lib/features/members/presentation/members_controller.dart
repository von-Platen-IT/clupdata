import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import 'package:drift/drift.dart';
import '../data/members_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'members_controller.g.dart';

// Since Riverpod Generator has trouble analyzing the Drift-generated `Member` type in a Stream,
// we fall back to a standard StreamProvider for the realtime data.

/// A global stream provider that automatically emits the current list of club members.
///
/// The UI can watch this provider (`ref.watch(membersStreamProvider)`) to
/// display a list of members that updates in real-time if the underlying database changes.
final membersStreamProvider = StreamProvider<List<Member>>((ref) {
  final repository = ref.watch(membersRepositoryProvider);
  return repository.watchAllMembers();
});

/// A Riverpod action controller that handles UI interactions related to members.
///
/// Rather than having business logic directly in button callbacks, the UI
/// calls methods on `MembersActions` (e.g. `ref.read(membersActionsProvider.notifier).addMember(...)`).
@riverpod
class MembersActions extends _$MembersActions {
  @override
  void build() {}

  /// Adds a new member to the system.
  ///
  /// Takes the user's [firstName] and [lastName], sets their join date to the
  /// current time, and marks them automatically as active. Forwards the payload
  /// to the database repository.
  Future<void> addMember({
    required String firstName,
    required String lastName,
  }) async {
    final repository = ref.read(membersRepositoryProvider);
    
    final newMember = MembersCompanion.insert(
      firstName: firstName,
      lastName: lastName,
      joinDate: DateTime.now(),
      isActive: true,
    );

    await repository.addMember(newMember);
  }

  /// Deactivates a member based on their database [id].
  Future<void> deactivateMember(int id) async {
     final repository = ref.read(membersRepositoryProvider);
     await repository.deactivateMember(id);
  }
}
