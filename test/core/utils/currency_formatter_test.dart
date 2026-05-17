import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    group('formatCurrencyEur', () {
      test('formats whole euros without decimals', () {
        expect(formatCurrencyEur(100), '100,00 €');
      });

      test('formats with cents', () {
        expect(formatCurrencyEur(123.45), '123,45 €');
      });

      test('formats thousands with dot separator', () {
        expect(formatCurrencyEur(1234.56), '1.234,56 €');
      });

      test('formats large numbers', () {
        expect(formatCurrencyEur(1000000), '1.000.000,00 €');
      });

      test('formats zero', () {
        expect(formatCurrencyEur(0), '0,00 €');
      });

      test('formats negative amounts', () {
        expect(formatCurrencyEur(-42.50), '-42,50 €');
      });

      test('rounds to 2 decimals', () {
        expect(formatCurrencyEur(99.999), '100,00 €');
      });
    });
  });
}
