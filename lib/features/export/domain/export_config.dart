import 'detail_export_provider.dart';

/// Configuration for export functionality in edit dialogs.
///
/// Supports two modes:
/// 1. **Provider mode** (preferred): Uses [detailProvider] to build
///    an [ExportDataTable] with ALL detail fields — no DataGrid dependency.
/// 2. **Legacy mode**: Uses [item] + [entityType] with DataGrid controller.
class ExportConfig {
  /// Detail export provider (preferred — uses dialog data directly).
  ///
  /// When set, the export buttons use this provider to build the
  /// export data, completely bypassing the DataGrid controller.
  final DetailExportProvider? detailProvider;

  /// The item to export (legacy — for DataGrid-based export).
  final dynamic item;

  /// The entity type identifier (e.g., 'mitglied', 'rechnung').
  final String entityType;

  /// The display title for the export.
  final String title;

  /// Optional subtitle or description.
  final String? subtitle;

  const ExportConfig({
    this.detailProvider,
    this.item,
    required this.entityType,
    required this.title,
    this.subtitle,
  });

  /// Returns true if this config has a detail provider.
  bool get hasDetailProvider => detailProvider != null;
}
