import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/export_context_data.dart';
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
///
/// The optional [ExportGenerator] is registered alongside the controller
/// so that export actions can capture a snapshot of the grid's visual state
/// without coupling to any specific UI widget.
@Riverpod(keepAlive: true)
class ActiveDataGridController extends _$ActiveDataGridController {
  ExportGenerator? _exportGenerator;

  @override
  DataGridController<dynamic>? build() => null;

  /// Registers a [DataGridController] as the currently active one,
  /// along with an optional [exportGenerator] that can capture the
  /// grid's current visual state into an [ExportContextData] snapshot.
  void register(
    DataGridController<dynamic> controller, {
    ExportGenerator? exportGenerator,
  }) {
    state = controller;
    _exportGenerator = exportGenerator;
  }

  /// Clears the active controller reference and export generator
  /// (e.g. when the grid unmounts).
  void unregister() {
    state = null;
    _exportGenerator = null;
  }

  /// Returns the export generator function for the currently active grid,
  /// or `null` if no grid is active or the grid has no export capability.
  ExportGenerator? get exportGenerator => _exportGenerator;
}
