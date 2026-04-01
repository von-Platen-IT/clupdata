import 'package:flutter/material.dart';

import 'pdf_template.dart';
import 'pdf_template_registry.dart';

/// Dropdown widget for selecting a PDF template.
///
/// Filters templates based on export context (list vs. detail view)
/// and optionally by entity type. Provides a user-friendly dropdown
/// with German display names.
///
/// Example usage:
/// ```dart
/// PdfTemplateSelector(
///   selectedTemplate: currentTemplate,
///   isDetailView: false,
///   entityType: 'mitglied',
///   onChanged: (template) {
///     if (template != null) {
///       setState(() => currentTemplate = template);
///     }
///   },
/// )
/// ```
class PdfTemplateSelector extends StatelessWidget {
  /// The currently selected template.
  final PdfTemplate? selectedTemplate;

  /// Callback when the selection changes.
  final ValueChanged<PdfTemplate?> onChanged;

  /// Whether the export is for a detail view (single item).
  final bool isDetailView;

  /// Optional entity type for filtering (e.g., 'rechnung', 'mitglied').
  final String? entityType;

  /// Optional label text for the dropdown.
  final String labelText;

  /// Creates a [PdfTemplateSelector] with the given configuration.
  const PdfTemplateSelector({
    super.key,
    this.selectedTemplate,
    required this.onChanged,
    required this.isDetailView,
    this.entityType,
    this.labelText = 'Vorlage',
  });

  @override
  Widget build(BuildContext context) {
    final templates = _getFilteredTemplates();
    final theme = Theme.of(context);

    // Ensure selected template is in the list
    var effectiveSelection = selectedTemplate;
    if (effectiveSelection != null && !templates.contains(effectiveSelection)) {
      effectiveSelection = null;
    }

    return DropdownButtonFormField<PdfTemplate>(
      initialValue: effectiveSelection,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.style_outlined, size: 20),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
      ),
      items: templates.map((template) {
        return DropdownMenuItem<PdfTemplate>(
          value: template,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  template.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (template.category != PdfTemplateCategory.generic)
                _buildCategoryChip(template.category),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      hint: Text(
        'Vorlage auswählen...',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Builds a small chip showing the template category.
  Widget _buildCategoryChip(PdfTemplateCategory category) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getCategoryColor(category).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getCategoryColor(category).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        category.displayName,
        style: TextStyle(
          fontSize: 10,
          color: _getCategoryColor(category),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Returns a color for each category.
  Color _getCategoryColor(PdfTemplateCategory category) {
    switch (category) {
      case PdfTemplateCategory.generic:
        return Colors.grey;
      case PdfTemplateCategory.invoice:
        return Colors.blue;
      case PdfTemplateCategory.member:
        return Colors.green;
      case PdfTemplateCategory.list:
        return Colors.orange;
      case PdfTemplateCategory.detail:
        return Colors.purple;
    }
  }

  /// Filters templates based on current context.
  List<PdfTemplate> _getFilteredTemplates() {
    return PdfTemplateRegistry.getSuitableFor(
      isDetailView: isDetailView,
      entityType: entityType,
    );
  }
}

/// A more compact version of the template selector for toolbars.
class PdfTemplateSelectorCompact extends StatelessWidget {
  /// The currently selected template.
  final PdfTemplate? selectedTemplate;

  /// Callback when the selection changes.
  final ValueChanged<PdfTemplate?> onChanged;

  /// Whether the export is for a detail view (single item).
  final bool isDetailView;

  /// Optional entity type for filtering.
  final String? entityType;

  /// Creates a compact [PdfTemplateSelectorCompact].
  const PdfTemplateSelectorCompact({
    super.key,
    this.selectedTemplate,
    required this.onChanged,
    required this.isDetailView,
    this.entityType,
  });

  @override
  Widget build(BuildContext context) {
    final templates = PdfTemplateRegistry.getSuitableFor(
      isDetailView: isDetailView,
      entityType: entityType,
    );

    return DropdownButton<PdfTemplate>(
      value: selectedTemplate,
      isDense: true,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.arrow_drop_down, size: 20),
      items: templates.map((template) {
        return DropdownMenuItem<PdfTemplate>(
          value: template,
          child: Text(template.displayName),
        );
      }).toList(),
      onChanged: onChanged,
      hint: const Text('Vorlage'),
    );
  }
}
