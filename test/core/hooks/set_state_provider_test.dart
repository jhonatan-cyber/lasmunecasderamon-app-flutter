import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/hooks/set_state_provider.dart';

void main() {
  group('FormUIState', () {
    test('default values', () {
      final state = const FormUIState();
      expect(state.isSubmitting, false);
      expect(state.error, isNull);
      expect(state.flags, {});
    });

    test('copyWith updates isSubmitting', () {
      final state = const FormUIState().copyWith(isSubmitting: true);
      expect(state.isSubmitting, true);
      expect(state.error, isNull);
    });

    test('copyWith sets error', () {
      final state = const FormUIState().copyWith(error: 'Algo salió mal');
      expect(state.error, 'Algo salió mal');
    });

    test('copyWith clearError clears error', () {
      final state = const FormUIState(error: 'error viejoo')
          .copyWith(clearError: true);
      expect(state.error, isNull);
    });

    test('copyWith clearError takes precedence over error param', () {
      final state = const FormUIState(error: 'viejoo')
          .copyWith(clearError: true, error: 'nuevoo');
      expect(state.error, isNull); 
    });

    test('copyWith updates flags', () {
      final state = const FormUIState().copyWith(
        flags: {'obscurePassword': true},
      );
      expect(state.flags['obscurePassword'], true);
    });

    test('copyWith merges empty flags when not provided', () {
      final state = const FormUIState(flags: {'existing': true})
          .copyWith(isSubmitting: true);
      expect(state.flags['existing'], true);
    });
  });

  group('SetStateNotifier', () {
    late SetStateNotifier notifier;

    setUp(() {
      notifier = SetStateNotifier();
    });

    test('initial state', () {
      expect(notifier.state.isSubmitting, false);
      expect(notifier.state.error, isNull);
    });

    group('submission', () {
      test('setSubmitting(true)', () {
        notifier.setSubmitting(true);
        expect(notifier.state.isSubmitting, true);
      });

      test('setSubmitting(false)', () {
        notifier.setSubmitting(true);
        notifier.setSubmitting(false);
        expect(notifier.state.isSubmitting, false);
      });

      test('startSubmit sets submitting and clears error', () {
        notifier.setError('viejoo');
        notifier.startSubmit();
        expect(notifier.state.isSubmitting, true);
        expect(notifier.state.error, isNull);
      });

      test('endSubmit clears submitting, keeps error', () {
        notifier.setSubmitting(true);
        notifier.setError('error');
        notifier.endSubmit();
        expect(notifier.state.isSubmitting, false);
        expect(notifier.state.error, 'error');
      });
    });

    group('error', () {
      test('setError stores the message', () {
        notifier.setError('Error de conexión');
        expect(notifier.state.error, 'Error de conexión');
      });

      test('setError(null) clears', () {
        notifier.setError('Algo');
        notifier.setError(null);
        expect(notifier.state.error, isNull);
      });

      test('clearError clears error', () {
        notifier.setError('Algo');
        notifier.clearError();
        expect(notifier.state.error, isNull);
      });
    });

    group('flags', () {
      test('setFlag stores the value', () {
        notifier.setFlag('obscurePassword', true);
        expect(notifier.state.flags['obscurePassword'], true);
      });

      test('setFlag overwrites existing', () {
        notifier.setFlag('loadingDetail', false);
        expect(notifier.state.flags['loadingDetail'], false);
      });

      test('toggleFlag flips false→true', () {
        notifier.toggleFlag('someFlag');
        expect(notifier.state.flags['someFlag'], true);
      });

      test('toggleFlag flips true→false', () {
        notifier.setFlag('someFlag', true);
        notifier.toggleFlag('someFlag');
        expect(notifier.state.flags['someFlag'], false);
      });

      test('multiple flags coexist', () {
        notifier.setFlag('a', true);
        notifier.setFlag('b', false);
        expect(notifier.state.flags['a'], true);
        expect(notifier.state.flags['b'], false);
      });
    });

    group('guard', () {
      test('sets submitting, then clears on success', () async {
        final ok = await notifier.guard(() async {});
        expect(ok, true);
        expect(notifier.state.isSubmitting, false);
        expect(notifier.state.error, isNull);
      });

      test('sets error on failure, returns false, clears submitting', () async {
        final ok = await notifier.guard(() async {
          throw Exception('Algo falló');
        });
        expect(ok, false);
        expect(notifier.state.isSubmitting, false);
        expect(notifier.state.error, 'Algo falló');
      });

      test('strips "Exception: " prefix from messages', () async {
        await notifier.guard(() async {
          throw Exception('Error de red');
        });
        expect(notifier.state.error, 'Error de red');
      });

      test('handles plain string errors without prefix stripping', () async {
        await notifier.guard(() async {
          throw 'Error simple';
        });
        expect(notifier.state.error, 'Error simple');
      });

      test('clears previous error before running', () async {
        notifier.setError('error viejoo');
        await notifier.guard(() async {});
        expect(notifier.state.error, isNull);
      });
    });
  });
}
