import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'sales_repository.g.dart';

/// A repository for handling Point-of-Sale (POS) transactions.
///
/// It isolates Drift database operations for the `Sales` table, allowing
/// the UI to easily fetch history or record new purchases.
class SalesRepository {
  final AppDatabase _db;

  /// Creates a [SalesRepository] with a required database connection.
  SalesRepository(this._db);

  /// Returns a real-time reactive stream of the 100 most recent sales.
  ///
  /// The sales are ordered by [saleDate] in descending order (newest first).
  Stream<List<Sale>> watchRecentSales() {
    return (_db.select(_db.sales)
          ..orderBy([(s) => OrderingTerm(expression: s.saleDate, mode: OrderingMode.desc)])
          ..limit(100))
        .watch();
  }

  /// Inserts a newly completed POS [sale] into the database.
  Future<int> addSale(SalesCompanion sale) {
    return _db.into(_db.sales).insert(sale);
  }
}

/// Riverpod provider for the [SalesRepository].
@riverpod
SalesRepository salesRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return SalesRepository(db);
}
