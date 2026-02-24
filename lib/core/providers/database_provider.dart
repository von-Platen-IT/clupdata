import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../database/database.dart';

part 'database_provider.g.dart';

/// Provides a global singleton instance of the [AppDatabase].
///
/// This Riverpod provider ensures that the entire application shares a single
/// database connection pool. Setting `keepAlive: true` prevents the database
/// connection from closing unexpectedly when UI components are disposed.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}
