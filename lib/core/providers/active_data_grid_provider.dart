import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../widgets/data_grid_v2/data_grid_controller.dart';

part 'active_data_grid_provider.g.dart';

/// Global provider that holds a reference to the currently active
/// [DataGridController] from whichever feature screen is visible.
///
/// This allows the top-level menu bar (MainMenuBar) to access the
/// grid's data for export, print, and analytics operations without
/// coupling the menu to any specific feature.
///
/// Each [VpitDataGrid] instance registers its controller on mount
/// and unregisters it on unmount via this provider.
@Riverpod(keepAlive: true)
class ActiveDataGridController extends _$ActiveDataGridController {
  @override
  DataGridController<dynamic>? build() => null;

  /// Registers a [DataGridController] as the currently active one.
  void register(DataGridController<dynamic> controller) {
    state = controller;
  }

  /// Clears the active controller reference (e.g. when the grid unmounts).
  void unregister() {
    state = null;
  }
}
