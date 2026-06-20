import 'package:flutter_riverpod/flutter_riverpod.dart';











class FormUIState {
  final bool isSubmitting;
  final String? error;
  final Map<String, bool> flags;

  const FormUIState({
    this.isSubmitting = false,
    this.error,
    this.flags = const {},
  });

  
  static const _errorSentinel = Object();

  
  
  
  
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
                : error as String?),  
      flags: flags ?? this.flags,
    );
  }

  @override
  String toString() =>
      'FormUIState(isSubmitting: $isSubmitting, error: $error, flags: $flags)';
}


















































class SetStateNotifier extends StateNotifier<FormUIState> {
  SetStateNotifier() : super(const FormUIState());

  

  
  void setSubmitting(bool value) => state = state.copyWith(isSubmitting: value);

  
  void startSubmit() => state = state.copyWith(isSubmitting: true, clearError: true);

  
  void endSubmit() => state = state.copyWith(isSubmitting: false);

  
  
  
  
  
  
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

  

  
  
  void setError(String? error) => state = state.copyWith(error: error);

  
  void clearError() => state = state.copyWith(clearError: true);

  

  
  void setFlag(String key, bool value) {
    state = state.copyWith(flags: {...state.flags, key: value});
  }

  
  void toggleFlag(String key) {
    state = state.copyWith(
      flags: {...state.flags, key: !(state.flags[key] ?? false)},
    );
  }

  

  String _extractMessage(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}









final setStateProvider = StateNotifierProvider.autoDispose
    .family<SetStateNotifier, FormUIState, String>(
  (ref, formId) => SetStateNotifier(),
);
