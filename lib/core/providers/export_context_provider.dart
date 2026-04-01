import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../widgets/data_grid_v2/export/export_data_table.dart';

/// Represents the current export mode.
enum ExportMode {
  /// Export from a list/grid view (default).
  list,

  /// Export from a detail dialog (single item).
  detail,

  /// Export with full data including relations.
  full,
}

/// Data class holding the current export context snapshot.
///
/// This is a pure OOP data container that completely isolates the export
/// generation process from the UI widgets (like PlutoGrid) or controllers.
class ExportContextData {
  /// The export mode (list, detail, full).
  final ExportMode mode;

  /// The cached data table snapshot (visible columns only).
  final ExportDataTable dataTable;

  /// The cached data table snapshot containing ALL columns (even hidden ones).
  /// Used for the "Alle Details" export option.
  final ExportDataTable? fullDataTable;

  /// The active filters at the time of the snapshot.
  final Map<String, String> activeFilters;

  /// The active sort descriptions at the time of the snapshot.
  final List<String> activeSorts;

  /// The entity type identifier (e.g., 'mitglied', 'rechnung').
  final String? entityType;

  /// The display title for the export.
  final String title;

  /// Optional subtitle or description.
  final String? subtitle;

  const ExportContextData({
    required this.mode,
    required this.dataTable,
    this.fullDataTable,
    this.activeFilters = const {},
    this.activeSorts = const [],
    this.entityType,
    required this.title,
    this.subtitle,
  });

  /// Returns true if this is a detail export context.
  bool get isDetail => mode == ExportMode.detail;

  /// Returns true if this is a list export context.
  bool get isList => mode == ExportMode.list;

  /// Returns the effective entity type for template filtering.
  String? get effectiveEntityType => entityType;

  @override
  String toString() {
    return 'ExportContextData(mode: $mode, entityType: $entityType, title: $title)';
  }
}

/// Extension for convenient context checking.
extension ExportContextExtension on ExportContextData? {
  bool get hasContext => this != null;
  bool get isDetail => this?.isDetail ?? false;
  bool get isList => this?.isList ?? false;
  String? get entityType => this?.entityType;
}

/// Global provider holding a generator function for the latest export snapshot.
///
/// UI widgets (like VpitDataGrid) register a function here that can
/// synchronously capture their current visual state into a pure OOP container.
/// Export actions (like PDF generation) call this function to get the snapshot,
/// completely decoupling them from the UI.
typedef ExportGenerator = ExportContextData? Function();

class ExportCacheNotifier extends Notifier<ExportGenerator?> {
  final List<ExportGenerator> _stack = [];

  @override
  ExportGenerator? build() => null;

  void pushGenerator(ExportGenerator generator) {
    if (!_stack.contains(generator)) {
      _stack.add(generator);
    } else {
      // Move to top if already exists
      _stack.remove(generator);
      _stack.add(generator);
    }
    state = generator;
  }

  void removeGenerator(ExportGenerator generator) {
    _stack.remove(generator);
    state = _stack.isEmpty ? null : _stack.last;
  }
}

final exportCacheProvider = NotifierProvider<ExportCacheNotifier, ExportGenerator?>(
  ExportCacheNotifier.new,
);
