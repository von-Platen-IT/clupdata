import 'package:intl/intl.dart';

/// Zentraler DateFormatter für dd.MM.yyyy Format.
/// Wird nur einmal instanziiert statt bei jedem Widget-Build (Issue 3.2).
final dateFormatter = DateFormat('dd.MM.yyyy');

/// Zentraler CurrencyFormatter für deutsches Währungsformat.
/// Wird nur einmal instanziiert statt bei jedem Widget-Build.
final currencyFormatter = NumberFormat.currency(locale: 'de_DE', symbol: '€');
