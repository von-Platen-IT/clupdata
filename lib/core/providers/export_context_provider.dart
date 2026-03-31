import 'package:flutter/material.dart';

import '../../widgets/data_grid_v2/data_grid_controller.dart';

/// Represents the current export mode.
enum ExportMode {
  /// Export from a list/grid view (default).
  list,

  /// Export from a detail dialog (single item).
  detail,

  /// Export with full data including relations.
  full,
}

/// Data class holding the current export context.
class ExportContextData {
  /// The export mode (list, detail, full).
  final ExportMode mode;

  /// The controller for list exports (null for detail exports).
  final DataGridController<dynamic>? controller;

  /// The single item for detail exports (null for list exports).
  final dynamic item;

  /// The entity type identifier (e.g., 'mitglied', 'rechnung').
  final String? entityType;

  /// The display title for the export.
  final String title;

  /// Optional subtitle or description.
  final String? subtitle;

  const ExportContextData({
    required this.mode,
    this.controller,
    this.item,
    this.entityType,
    required this.title,
    this.subtitle,
  });

  /// Returns true if this is a detail export context.
  bool get isDetail => mode == ExportMode.detail || item != null;

  /// Returns true if this is a list export context.
  bool get isList => mode == ExportMode.list || controller != null;

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
