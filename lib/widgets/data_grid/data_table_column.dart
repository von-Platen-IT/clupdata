import 'package:flutter/material.dart';

/// Defines a column configuration for the AppDataTable.
class DataTableColumn<T> {
  /// The header label for this column.
  final String label;

  /// Function to extract the string value for this column. Used for sorting, filtering, and default rendering.
  /// This is required unless a custom `cellBuilder` is provided that doesn't rely on string extraction.
  final String Function(T item)? valueExtractor;

  /// Optional custom builder for the cell UI. If null, a simple Text widget with `valueExtractor` is used.
  final Widget Function(T item)? cellBuilder;

  /// Optional function to extract a strongly typed `Comparable` value (like `DateTime` or `num`) for correct sorting.
  /// If not provided, sorting will fall back to the string from `valueExtractor`.
  final Comparable? Function(T item)? sortExtractor;

  /// Optional fixed width. If null, the column will use the `flex` value to expand.
  final double? fixedWidth;

  /// Flex factor for expanding columns. Ignored if `fixedWidth` is set. Default is 1.
  final int flex;

  /// Alignment of the cell content. Default is centerLeft.
  final AlignmentGeometry alignment;

  /// Whether this column can be used to sort the data. Default is false.
  final bool sortable;

  const DataTableColumn({
    required this.label,
    this.valueExtractor,
    this.cellBuilder,
    this.sortExtractor,
    this.fixedWidth,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
    this.sortable = false,
  }) : assert(valueExtractor != null || cellBuilder != null, 'Either valueExtractor or cellBuilder must be provided');
}
