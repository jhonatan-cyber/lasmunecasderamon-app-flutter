import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the loading/refreshing state for a screen that fetches data.
///
/// Separates the two states so the UI can show a skeleton on first load
/// and only a subtle indicator on manual pull-to-refresh.
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

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages the refresh lifecycle for a screen.
///
/// Typical usage inside a [ConsumerState] or [ConsumerWidget]:
///
/// ```dart
/// final refresh = ref.watch(refreshProvider('myScreen'));
/// final notifier = ref.read(refreshProvider('myScreen').notifier);
///
/// Future<void> _fetchData({bool isManual = false}) async {
///   notifier.startRefresh(isManual: isManual);
///   try {
///     // ... API calls ...
///     notifier.endRefresh();
///     if (isManual) notifier.showSuccessSnack(context, 'Datos actualizados');
///   } catch (e) {
///     notifier.endRefresh(error: 'Error al cargar datos');
///   }
/// }
/// ```
class RefreshNotifier extends StateNotifier<RefreshState> {
  RefreshNotifier() : super(const RefreshState());

  /// Call at the start of a fetch operation.
  /// Sets [isRefreshing] when triggered by pull-to-refresh,
  /// and [isLoading] when it's the initial load.
  void startRefresh({required bool isManual}) {
    state = state.copyWith(
      isRefreshing: isManual,
      isLoading: !isManual,
      clearError: true,
    );
  }

  /// Call when the fetch completes (success or failure).
  /// Pass an [error] message to display it in the UI.
  void endRefresh({String? error}) {
    state = state.copyWith(
      isLoading: false,
      isRefreshing: false,
      error: error,
    );
  }

  /// Shows a floating success snackbar (only intended for pull-to-refresh).
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

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable provider that gives each screen its own refresh state.
///
/// Use a unique [screenId] per screen (e.g. `'propinas'`, `'asistencia'`).
/// The provider auto-disposes when the screen is removed from the widget tree.
final refreshProvider = StateNotifierProvider.autoDispose
    .family<RefreshNotifier, RefreshState, String>(
  (ref, screenId) => RefreshNotifier(),
);
