/// Shared currency formatting utilities for German locale (€).
///
/// Centralizes the duplicated `_formatCurrency` methods previously
/// found in [RechnungenSummaryGenerator] and [WarenSummaryGenerator].
///
/// Format: `1.234,56 €` (amount with 2 decimals, comma as decimal separator,
/// dot as thousands separator, € symbol after amount).
String formatCurrencyEur(double amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final integerPart = _formatWithThousandsSeparator(parts[0]);
  return '$integerPart,${parts[1]} €';
}

/// Inserts dots as thousands separators into the integer part string.
String _formatWithThousandsSeparator(String integerPart) {
  if (integerPart.length <= 3) return integerPart;

  final result = StringBuffer();
  final length = integerPart.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) {
      result.write('.');
    }
    result.write(integerPart[i]);
  }
  return result.toString();
}
