import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/export_data_repository.dart';
import 'database_provider.dart';

part 'export_data_repository_provider.g.dart';

/// Provider for the [ExportDataRepository].
///
/// This repository provides headless data fetching for export purposes,
/// applying filters and sorts at the database level.
@riverpod
ExportDataRepository exportDataRepository(Ref ref) {
  return ExportDataRepository(ref.watch(appDatabaseProvider));
}
