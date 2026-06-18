import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/utils/time_utils.dart';

void main() {
  group('TimeUtils', () {
    group('parseDateSafe', () {
      test('parses ISO 8601 datetime', () {
        final result = TimeUtils.parseDateSafe('2024-06-17T14:30:00.000Z');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 6);
        expect(result.day, 17);
      });

      test('parses yyyy-MM-dd format', () {
        final result = TimeUtils.parseDateSafe('2024-06-17');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 6);
        expect(result.day, 17);
      });

      test('returns null for null input', () {
        expect(TimeUtils.parseDateSafe(null), isNull);
      });

      test('returns null for empty string', () {
        expect(TimeUtils.parseDateSafe(''), isNull);
      });

      test('returns null for invalid date', () {
        expect(TimeUtils.parseDateSafe('not-a-date'), isNull);
      });
    });

    group('calculateRemainingTime', () {
      test('returns positive seconds for future date', () {
        final future = DateTime.now().add(const Duration(minutes: 5));
        final remaining = TimeUtils.calculateRemainingTime(future);
        expect(remaining, greaterThan(200));
        expect(remaining, lessThan(310));
      });

      test('returns 0 for past date', () {
        final past = DateTime.now().subtract(const Duration(minutes: 5));
        expect(TimeUtils.calculateRemainingTime(past), 0);
      });
    });

    group('formatRemaining', () {
      test('formats seconds as minutes', () {
        expect(TimeUtils.formatRemaining(2700), '45 min');
      });

      test('formats seconds as hours and minutes', () {
        expect(TimeUtils.formatRemaining(5000), '1h 23min');
      });

      test('returns "0 min" for 0 or negative', () {
        expect(TimeUtils.formatRemaining(0), '0 min');
        expect(TimeUtils.formatRemaining(-1), '0 min');
      });
    });

    group('timeAgo', () {
      test('returns "ahora" for recent time', () {
        final now = DateTime.now();
        expect(TimeUtils.timeAgo(now), 'ahora');
      });

      test('returns minutes ago', () {
        final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(TimeUtils.timeAgo(fiveMinAgo), 'hace 5 min');
      });

      test('returns hours ago', () {
        final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
        expect(TimeUtils.timeAgo(twoHoursAgo), 'hace 2h');
      });
    });

    group('isToday', () {
      test('returns true for today', () {
        expect(TimeUtils.isToday(DateTime.now()), isTrue);
      });

      test('returns false for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(TimeUtils.isToday(yesterday), isFalse);
      });
    });
  });
}
