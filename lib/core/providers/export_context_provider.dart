import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/export_context_data.dart';
import 'active_data_grid_provider.dart';

// Re-export types from the model file so existing imports continue to work.
export '../models/export_context_data.dart';

/// Convenience provider that exposes the [ExportGenerator] from the currently
/// active [DataGridController] registration.
///
/// UI widgets (like [ListExportMenuButton]) read this provider to capture an
/// [ExportContextData] snapshot for PDF/CSV/print export, completely decoupled
/// from any specific UI widget.
///
/// The generator is registered alongside the controller in
/// [ActiveDataGridController.register] and cleared on [ActiveDataGridController.unregister].
final exportCacheProvider = Provider<ExportGenerator?>((ref) {
  // Watch the active controller so this provider recomputes when it changes.
  ref.watch(activeDataGridControllerProvider);
  // Read the export generator stored in the controller's registration.
  return ref.read(activeDataGridControllerProvider.notifier).exportGenerator;
});
