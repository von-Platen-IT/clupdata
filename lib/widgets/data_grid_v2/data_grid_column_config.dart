import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

/// Type-safe column configuration for [VpitDataGrid].
///
/// Wraps all PlutoGrid column settings and provides a [valueExtractor]
/// function to map domain objects of type [T] to cell values. This
/// decouples the grid widget from any specific data model.
class DataGridColumnConfig<T> {
  /// Unique identifier matching the PlutoColumn field name.
  final String field;

  /// Display title shown in the column header.
  final String title;

  /// PlutoGrid column data type (text, number, date, etc.).
  final PlutoColumnType type;

  /// Whether inline editing is enabled for this column.
  /// Computed/read-only columns MUST set this to `false`.
  final bool editable;

  /// Whether sorting is enabled for this column header click.
  final bool sortable;

  /// Whether this column appears in the column filter dialog.
  final bool filterable;

  /// Horizontal text alignment for cell content.
  final PlutoColumnTextAlign textAlign;

  /// Horizontal text alignment for the column title.
  final PlutoColumnTextAlign titleTextAlign;

  /// Optional formatter for display values (e.g. currency formatting).
  final String Function(dynamic value)? formatter;

  /// Extracts the cell value from a domain object of type [T].
  /// This is the core mapping function from domain → grid cell.
  final dynamic Function(T item) valueExtractor;

  /// Optional custom renderer for the cell (e.g. for badges or icons).
  final Widget Function(PlutoColumnRendererContext context)? renderer;

  /// Optional minimum column width.
  final double? minWidth;

  /// Optional default column width.
  final double? width;

  const DataGridColumnConfig({
    required this.field,
    required this.title,
    required this.type,
    required this.valueExtractor,
    this.editable = false,
    this.sortable = true,
    this.filterable = true,
    this.textAlign = PlutoColumnTextAlign.left,
    this.titleTextAlign = PlutoColumnTextAlign.left,
    this.formatter,
    this.renderer,
    this.minWidth,
    this.width,
  });

  /// Creates a [PlutoColumn] from this configuration.
  ///
  /// Used internally by [VpitDataGrid] to build the column list
  /// for the PlutoGrid widget.
  PlutoColumn toPlutoColumn() {
    return PlutoColumn(
      title: title,
      field: field,
      type: type,
      enableEditingMode: editable,
      enableSorting: sortable,
      enableFilterMenuItem: filterable,
      textAlign: textAlign,
      titleTextAlign: titleTextAlign,
      formatter: formatter,
      renderer: renderer,
      minWidth: minWidth ?? PlutoGridSettings.minColumnWidth,
      width: width ?? PlutoGridSettings.columnWidth,
    );
  }

  /// Serializes column metadata to a JSON-compatible map.
  Map<String, dynamic> toMetadataMap() => {
        'field': field,
        'title': title,
        'editable': editable,
        'sortable': sortable,
        'filterable': filterable,
      };
}
