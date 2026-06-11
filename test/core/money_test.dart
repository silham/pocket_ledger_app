import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/money/money.dart';

void main() {
  group('parseAmountToMinor', () {
    test('parses whole and decimal amounts exactly', () {
      expect(parseAmountToMinor('450'), 450_00);
      expect(parseAmountToMinor('450.5'), 450_50);
      expect(parseAmountToMinor('450.55'), 450_55);
      expect(parseAmountToMinor('0.01'), 1);
      expect(parseAmountToMinor('1,250.75'), 1250_75);
      expect(parseAmountToMinor(' 99 '), 99_00);
    });

    test('rejects invalid input', () {
      expect(parseAmountToMinor(''), isNull);
      expect(parseAmountToMinor('abc'), isNull);
      expect(parseAmountToMinor('0'), isNull);
      expect(parseAmountToMinor('-5'), isNull);
      expect(parseAmountToMinor('1.999'), isNull, reason: 'max 2 decimals');
    });

    test('handles amounts that would lose precision as doubles', () {
      // 0.1 + 0.2 style cases: string -> minor units must be exact.
      expect(parseAmountToMinor('0.29'), 29);
      expect(parseAmountToMinor('1000000000.01'), 100000000001);
    });
  });

  group('formatMinor', () {
    test('formats with symbol, thousands separators and sign', () {
      expect(formatMinor(450_50), 'Rs. 450.50');
      expect(formatMinor(1250000), 'Rs. 12,500.00');
      expect(formatMinor(-45050), '-Rs. 450.50');
      expect(formatMinor(0), 'Rs. 0.00');
    });
  });
}
