import 'package:pdf/widgets.dart' as pw;

import '../export_data_table.dart';
import 'pdf_export_context.dart';

/// Categories for organizing PDF templates in selection UIs.
enum PdfTemplateCategory {
  /// Generic table layouts suitable for any data.
  generic,

  /// Invoice and financial document layouts.
  invoice,

  /// Member-related document layouts.
  member,

  /// List and overview layouts.
  list,

  /// Detail view layouts for single items.
  detail,
}

/// Extension to get display names for categories.
extension PdfTemplateCategoryName on PdfTemplateCategory {
  String get displayName {
    switch (this) {
      case PdfTemplateCategory.generic:
        return 'Allgemein';
      case PdfTemplateCategory.invoice:
        return 'Rechnung';
      case PdfTemplateCategory.member:
        return 'Mitglied';
      case PdfTemplateCategory.list:
        return 'Liste';
      case PdfTemplateCategory.detail:
        return 'Detail';
    }
  }
}

/// Interface for PDF layout templates.
///
/// Implementations define how [ExportDataTable] data is rendered into
/// a PDF document. The template system supports two modes:
///
/// 1. **Simple Mode**: Generic table layouts without decoration
///    (e.g., [SimpleTableTemplate])
///
/// 2. **Template Mode**: Domain-specific layouts with logos, headers,
///    footers, and custom formatting (e.g., invoice layouts)
///
/// Templates are registered via [PdfTemplateRegistry] and selected
/// by the user or application logic at export time.
///
/// Example implementation:
/// ```dart
/// class InvoicePdfTemplate implements PdfTemplate {
///   @override
///   String get displayName => 'Rechnungs-Layout';
///
///   @override
///   bool get supportsDetailView => true;
///
///   @override
///   PdfTemplateCategory get category => PdfTemplateCategory.invoice;
///
///   @override
///   List<String>? get supportedEntityTypes => ['rechnung', 'angebot'];
///
///   @override
///   Future<pw.Document> generate(
///     ExportDataTable dataTable,
///     PdfExportContext context,
///   ) async {
///     final pdf = pw.Document();
///     // ... build PDF structure
///     return pdf;
///   }
/// }
/// ```
abstract class PdfTemplate {
  /// The display name shown in template selection UIs.
  String get displayName;

  /// Whether this template supports detail view (single item) exports.
  ///
  /// Some templates like invoice layouts only make sense for single
  /// items and should return `true`. Generic list templates should
  /// return `true` as well since they can render single-row tables.
  ///
  /// If `false`, the template will be hidden when exporting from
  /// a detail dialog context.
  bool get supportsDetailView;

  /// The category of this template for organization and filtering.
  ///
  /// Defaults to [PdfTemplateCategory.generic] if not overridden.
  PdfTemplateCategory get category => PdfTemplateCategory.generic;

  /// Optional list of entity types this template is designed for.
  ///
  /// Examples: 'rechnung', 'mitglied', 'beitrag'
  /// If null or empty, the template is considered suitable for any entity.
  List<String>? get supportedEntityTypes => null;

  /// Generates a PDF document from the given data and context.
  ///
  /// [dataTable] contains the pre-formatted tabular data extracted
  /// from [DataGridController].
  ///
  /// [context] provides metadata like title, timestamp, filters,
  /// and whether this is a detail view export.
  ///
  /// Returns a [pw.Document] that can be saved, printed, or previewed.
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  );
}

/// Extension for PdfTemplate helper methods.
extension PdfTemplateHelpers on PdfTemplate {
  /// Checks if this template supports the given entity type.
  bool supportsEntityType(String? entityType) {
    if (entityType == null || supportedEntityTypes == null) return true;
    return supportedEntityTypes!.any(
      (e) => e.toLowerCase() == entityType.toLowerCase(),
    );
  }

  /// Checks if this template is suitable for the given context.
  bool isSuitableFor({required bool isDetailView, String? entityType}) {
    // Check detail view compatibility
    if (isDetailView && !supportsDetailView) return false;

    // Check entity type compatibility
    if (!supportsEntityType(entityType)) return false;

    return true;
  }
}
