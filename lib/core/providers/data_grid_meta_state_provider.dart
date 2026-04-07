import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/data_grid_meta_state.dart';
import '../../widgets/data_grid_v2/sort_column_config.dart';

part 'data_grid_meta_state_provider.g.dart';

/// Global state manager for DataGrid metadata.
///
/// Stores metadata per entity type, allowing multiple grids to coexist
/// and enabling headless export access.
///
/// Usage:
/// ```dart
/// // Update state from VpitDataGrid
/// ref.read(dataGridMetaStateProvider.notifier).updateMetaState(
///   'mitglied',
///   DataGridMetaState(...),
/// );
///
/// // Read state for export
/// final metaState = ref.read(dataGridMetaStateProvider)['mitglied'];
/// ```
@riverpod
class DataGridMetaStateNotifier extends _$DataGridMetaStateNotifier {
  @override
  Map<String, DataGridMetaState> build() => {};

  /// Updates or creates metadata for a specific entity type.
  void updateMetaState(String entityType, DataGridMetaState newState) {
    state = {...state, entityType: newState};
  }

  /// Updates only filters for an entity type.
  void updateFilters(String entityType, Map<String, String> filters) {
    final current = state[entityType];
    if (current != null) {
      state = {
        ...state,
        entityType: current.copyWith(activeFilters: filters),
      };
    }
  }

  /// Updates only sorts for an entity type.
  void updateSorts(String entityType, List<SortColumnConfig> sorts) {
    final current = state[entityType];
    if (current != null) {
      state = {
        ...state,
        entityType: current.copyWith(activeSorts: sorts),
      };
    }
  }

  /// Updates visible columns for an entity type.
  void updateVisibleColumns(String entityType, List<String> columns) {
    final current = state[entityType];
    if (current != null) {
      state = {
        ...state,
        entityType: current.copyWith(visibleColumns: columns),
      };
    }
  }

  /// Updates search text for an entity type.
  void updateSearchText(String entityType, String searchText) {
    final current = state[entityType];
    if (current != null) {
      state = {
        ...state,
        entityType: current.copyWith(searchText: searchText),
      };
    }
  }

  /// Removes metadata for a specific entity type.
  void removeMetaState(String entityType) {
    state = Map.from(state)..remove(entityType);
  }

  /// Clears all metadata.
  void clearAll() {
    state = {};
  }
}
