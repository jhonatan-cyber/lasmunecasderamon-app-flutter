import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/utils/money_utils.dart';

void main() {
  group('MoneyUtils', () {
    // Note: es_PE locale formats as "1.500,00 S/" (non-breaking space
    // between number and symbol, period for thousands, comma for decimals).
    // We match the actual locale output in tests.

    group('format', () {
      test('formats whole number with decimals', () {
        expect(MoneyUtils.format(1500), '1.500,00\u00a0S/ ');
      });

      test('formats zero', () {
        expect(MoneyUtils.format(0), '0,00\u00a0S/ ');
      });

      test('formats decimal value', () {
        expect(MoneyUtils.format(99.5), '99,50\u00a0S/ ');
      });
    });

    group('formatWhole', () {
      test('formats without decimals', () {
        expect(MoneyUtils.formatWhole(1500), '1.500\u00a0S/ ');
      });
    });

    group('formatCompact', () {
      test('formats thousands with K', () {
        expect(MoneyUtils.formatCompact(1500), 'S/ 1.5K');
      });

      test('formats millions with M', () {
        expect(MoneyUtils.formatCompact(2500000), 'S/ 2.5M');
      });

      test('formats small numbers normally', () {
        expect(MoneyUtils.formatCompact(500), '500,00\u00a0S/ ');
      });
    });

    group('formatSigned', () {
      test('formats positive with + prefix', () {
        expect(MoneyUtils.formatSigned(1500), '+ 1.500,00\u00a0S/ ');
      });

      test('formats negative with - prefix', () {
        expect(MoneyUtils.formatSigned(-500), '- 500,00\u00a0S/ ');
      });
    });

    group('percent', () {
      test('formats ratio as percentage', () {
        expect(MoneyUtils.percent(0.15), '15%');
      });
    });

    group('parseSafe', () {
      test('parses number', () {
        expect(MoneyUtils.parseSafe(1500), 1500.0);
      });

      test('parses string number', () {
        expect(MoneyUtils.parseSafe('1500'), 1500.0);
      });

      test('returns 0 for null', () {
        expect(MoneyUtils.parseSafe(null), 0.0);
      });

      test('returns 0 for invalid string', () {
        expect(MoneyUtils.parseSafe('abc'), 0.0);
      });
    });
  });
}
