import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'contracts_repository.g.dart';

/// A repository managing data access for member contracts.
///
/// It isolates Drift database operations for the `Contracts` table from
/// the presentation layer.
class ContractsRepository {
  final AppDatabase _db;

  /// Creates a [ContractsRepository] with a required database connection.
  ContractsRepository(this._db);

  /// Returns a real-time reactive stream of all contracts belonging to a specific [memberId].
  Stream<List<Contract>> watchContractsForMember(int memberId) {
    return (_db.select(_db.contracts)..where((c) => c.memberId.equals(memberId))).watch();
  }

  /// Returns a real-time reactive stream of all contracts in the system.
  Stream<List<Contract>> watchAllContracts() {
    return _db.select(_db.contracts).watch();
  }

  /// Inserts a new [contract] into the database.
  ///
  /// Returns the auto-generated [id] of the newly inserted contract.
  Future<int> addContract(ContractsCompanion contract) {
    return _db.into(_db.contracts).insert(contract);
  }

  /// Updates an existing [contract] in the database.
  Future<bool> updateContract(Contract contract) {
    return _db.update(_db.contracts).replace(contract);
  }

  /// Permanently deletes a contract by its [id].
  Future<int> deleteContract(int id) {
    return (_db.delete(_db.contracts)..where((c) => c.id.equals(id))).go();
  }
}

/// Riverpod provider for the [ContractsRepository].
@riverpod
ContractsRepository contractsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ContractsRepository(db);
}
