import 'pdf_template.dart';
import 'simple_table_template.dart';

/// Central registry for PDF templates.
///
/// Templates are registered by a unique key and can be retrieved
/// by key or listed for UI selection. The registry maintains a
/// default simple template as fallback.
///
/// Registration should happen during app initialization or feature
/// module setup:
///
/// ```dart
/// // In main.dart or feature initialization
/// PdfTemplateRegistry.register('invoice', InvoicePdfTemplate());
/// PdfTemplateRegistry.register('member_card', MemberCardTemplate());
/// ```
///
/// Usage in export UI:
/// ```dart
/// final template = PdfTemplateRegistry.get('invoice')
///     ?? PdfTemplateRegistry.simple;
/// ```
class PdfTemplateRegistry {
  static final Map<String, PdfTemplate> _templates = {};

  /// The default simple table template used as fallback.
  static final PdfTemplate _simpleTemplate = SimpleTableTemplate();

  /// Prevents instantiation.
  PdfTemplateRegistry._();

  /// Registers a template under the given [key].
  ///
  /// If a template already exists under [key], it will be overwritten.
  static void register(String key, PdfTemplate template) {
    _templates[key] = template;
  }

  /// Retrieves the template registered under [key].
  ///
  /// Returns `null` if no template is found for the given key.
  static PdfTemplate? get(String key) => _templates[key];

  /// Returns all registered templates.
  static List<PdfTemplate> get all => _templates.values.toList();

  /// Returns all registered templates with their keys.
  static Map<String, PdfTemplate> get allWithKeys =>
      Map.unmodifiable(_templates);

  /// Returns the default simple table template.
  static PdfTemplate get simple => _simpleTemplate;

  /// Checks if a template is registered under the given [key].
  static bool has(String key) => _templates.containsKey(key);

  /// Unregisters the template under [key].
  ///
  /// Returns the removed template or `null` if no template was registered.
  static PdfTemplate? unregister(String key) => _templates.remove(key);

  /// Clears all registered templates.
  ///
  /// The default simple template is not affected by this operation.
  static void clear() => _templates.clear();
}
