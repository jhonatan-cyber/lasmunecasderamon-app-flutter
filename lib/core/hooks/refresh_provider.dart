import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';









class RefreshState {
  final bool isLoading;
  final bool isRefreshing;
  final String error;

  const RefreshState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.error = '',
  });

  RefreshState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
  }) {
    return RefreshState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? '' : (error ?? this.error),
    );
  }
}
























class RefreshNotifier extends StateNotifier<RefreshState> {
  RefreshNotifier() : super(const RefreshState());

  
  
  
  void startRefresh({required bool isManual}) {
    state = state.copyWith(
      isRefreshing: isManual,
      isLoading: !isManual,
      clearError: true,
    );
  }

  
  
  void endRefresh({String? error}) {
    state = state.copyWith(
      isLoading: false,
      isRefreshing: false,
      error: error,
    );
  }

  
  void showSuccessSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}









final refreshProvider = StateNotifierProvider.autoDispose
    .family<RefreshNotifier, RefreshState, String>(
  (ref, screenId) => RefreshNotifier(),
);
