import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

/// Holds ephemeral form/UI state that doesn't warrant a dedicated notifier.
///
/// Covers the common patterns found across form screens:
/// - `isSubmitting` — form submission in progress (spinner en botón)
/// - `error` — local error message (banner en formulario)
/// - `flags` — simple boolean toggles (password visibility, biometrics, detail loading)
class FormUIState {
  final bool isSubmitting;
  final String? error;
  final Map<String, bool> flags;

  const FormUIState({
    this.isSubmitting = false,
    this.error,
    this.flags = const {},
  });

  /// Sentinel to distinguish "not provided" from `null` in [copyWith].
  static const _errorSentinel = Object();

  /// Creates a copy with the given fields updated.
  ///
  /// Unlike [RefreshState.copyWith], this correctly handles setting
  /// `error` to `null` (use `error: null` to clear the error).
  FormUIState copyWith({
    bool? isSubmitting,
    Object? error = _errorSentinel,
    bool clearError = false,
    Map<String, bool>? flags,
  }) {
    return FormUIState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError
          ? null
          : (identical(error, _errorSentinel)
                ? this.error
                : error as String?),  // null is explicit: "clear the error"
      flags: flags ?? this.flags,
    );
  }

  @override
  String toString() =>
      'FormUIState(isSubmitting: $isSubmitting, error: $error, flags: $flags)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages ephemeral form/UI state for a screen.
///
/// Typical usage inside a [ConsumerState]:
///
/// ```dart
/// final form = ref.watch(setStateProvider('nueva_venta'));
/// final notifier = ref.read(setStateProvider('nueva_venta').notifier);
/// ```
///
/// ### Submit guard (recommended):
/// ```dart
/// ElevatedButton(
///   onPressed: form.isSubmitting ? null : () => notifier.guard(() => _submit()),
///   child: form.isSubmitting
///     ? const CircularProgressIndicator(...)
///     : const Text('Guardar'),
/// );
///
/// Future<void> _submit() async {
///   final client = ref.read(apiClientProvider);
///   await client.dio.post('/sales', data: {...});
///   if (mounted) context.pop();
/// }
/// ```
///
/// ### Manual submission + error (for custom flows):
/// ```dart
/// notifier.setSubmitting(true);
/// try {
///   await _doSomething();
/// } catch (e) {
///   notifier.setError('Error al procesar');
/// } finally {
///   if (mounted) notifier.setSubmitting(false);
/// }
/// ```
///
/// ### Flags (password visibility, detail loading, etc.):
/// ```dart
/// // Toggle password visibility
/// notifier.toggleFlag('obscurePassword');
///
/// // Check in build
/// final obscure = ref.watch(setStateProvider('login')).flags['obscurePassword'] ?? true;
/// ```
class SetStateNotifier extends StateNotifier<FormUIState> {
  SetStateNotifier() : super(const FormUIState());

  // ── Submission ────────────────────────────────────────────────────

  /// Sets [isSubmitting] to [value].
  void setSubmitting(bool value) => state = state.copyWith(isSubmitting: value);

  /// Starts submission. Equivalent to `setSubmitting(true)`.
  void startSubmit() => state = state.copyWith(isSubmitting: true, clearError: true);

  /// Ends submission. Equivalent to `setSubmitting(false)`.
  void endSubmit() => state = state.copyWith(isSubmitting: false);

  /// Wraps an async operation: sets [isSubmitting] → awaits [fn] → clears [isSubmitting].
  ///
  /// If [fn] throws, the error message is captured in [error] and the exception
  /// is **not** rethrown (the UI displays it via the error banner).
  ///
  /// Returns `true` on success, `false` on error.
  Future<bool> guard(Future<void> Function() fn) async {
    startSubmit();
    try {
      await fn();
      endSubmit();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: _extractMessage(e),
      );
      return false;
    }
  }

  // ── Error ────────────────────────────────────────────────────────

  /// Sets a local error message (shown as a banner in the form).
  /// Pass `null` to clear the error.
  void setError(String? error) => state = state.copyWith(error: error);

  /// Clears the error message.
  void clearError() => state = state.copyWith(clearError: true);

  // ── Boolean flags ────────────────────────────────────────────────

  /// Sets a named boolean flag (e.g. `'obscurePassword'`, `'loadingDetail'`).
  void setFlag(String key, bool value) {
    state = state.copyWith(flags: {...state.flags, key: value});
  }

  /// Toggles a named boolean flag.
  void toggleFlag(String key) {
    state = state.copyWith(
      flags: {...state.flags, key: !(state.flags[key] ?? false)},
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _extractMessage(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable provider for ephemeral form/UI state.
///
/// Use a unique [formId] per screen (e.g. `'nueva_venta'`, `'login'`).
/// The provider auto-disposes when the screen is removed from the widget tree.
final setStateProvider = StateNotifierProvider.autoDispose
    .family<SetStateNotifier, FormUIState, String>(
  (ref, formId) => SetStateNotifier(),
);
