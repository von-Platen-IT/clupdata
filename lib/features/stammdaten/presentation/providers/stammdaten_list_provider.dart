import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../data/stammdaten_repository.dart';

/// Provider that exposes the stream of all [StammdatenItem] entries.
/// This matches the structure used by other features (like Members) to feed
/// the AppDataGrid with reactive data directly from Drift.
final stammdatenGridRowsProvider = StreamProvider<List<StammdatenItem>>((ref) {
  return ref.watch(stammdatenRepositoryProvider).watchSettings();
});

/// Basic configuration schema (optional helper) for UI metadata
class StammdatenUiConfig {
  static const categories = ['finanzen', 'programm', 'firma', 'druck', 'sonstiges'];
  static const types = ['string', 'integer', 'float', 'boolean', 'date'];
}
