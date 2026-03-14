import 'package:flutter/material.dart';
import '../../domain/models/beitrag_status.dart';

/// A reusable badge widget for displaying BeitragStatus.
/// Used in DataGrids, Dialogs, and Status History.
class StatusBadge extends StatelessWidget {
  final BeitragStatus status;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool showBorder;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    this.showBorder = true,
  });

  /// Factory constructor for creating from string value.
  factory StatusBadge.fromString(
    String statusValue, {
    double fontSize = 12,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 2,
    ),
    bool showBorder = true,
  }) {
    return StatusBadge(
      status: BeitragStatus.fromString(statusValue),
      fontSize: fontSize,
      padding: padding,
      showBorder: showBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: status.backgroundColor,
        border: showBorder
            ? Border.all(color: status.backgroundColor.withOpacityPercent(0.5))
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: fontSize,
          color: status.textColor,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
