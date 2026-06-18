import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('required', () {
      test('returns error for null', () {
        expect(Validators.required(null), isNotNull);
      });

      test('returns error for empty', () {
        expect(Validators.required(''), isNotNull);
      });

      test('returns null for non-empty', () {
        expect(Validators.required('hello'), isNull);
      });
    });

    group('email', () {
      test('returns null for valid email', () {
        expect(Validators.email('test@example.com'), isNull);
      });

      test('returns error for invalid email', () {
        expect(Validators.email('not-an-email'), isNotNull);
      });

      test('returns error for empty', () {
        expect(Validators.email(''), isNotNull);
      });
    });

    group('password', () {
      test('returns null for valid password', () {
        expect(Validators.password('abc123'), isNull);
      });

      test('returns error for short password', () {
        expect(Validators.password('ab1'), isNotNull);
      });

      test('returns error for password without number', () {
        expect(Validators.password('abcdef'), isNotNull);
      });

      test('returns error for empty', () {
        expect(Validators.password(''), isNotNull);
      });
    });

    group('confirmPassword', () {
      test('returns null when passwords match', () {
        expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
      });

      test('returns error when passwords differ', () {
        expect(Validators.confirmPassword('abc123', 'xyz789'), isNotNull);
      });
    });

    group('phone', () {
      test('returns null for valid phone', () {
        expect(Validators.phone('999888777'), isNull);
      });

      test('returns error for too short', () {
        expect(Validators.phone('123'), isNotNull);
      });

      test('returns error for empty', () {
        expect(Validators.phone(''), isNotNull);
      });
    });

    group('run', () {
      test('returns null for valid RUN', () {
        expect(Validators.run('12345678-5'), isNull);
      });

      test('returns null for RUN with K', () {
        expect(Validators.run('12345678-K'), isNull);
      });

      test('returns null for RUN without dash', () {
        expect(Validators.run('123456785'), isNull);
      });

      test('returns error for too short RUN', () {
        expect(Validators.run('123'), isNotNull);
      });

      test('returns error for empty', () {
        expect(Validators.run(''), isNotNull);
      });
    });
  });
}
