import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/api_client.dart';
import '../../../core/logger.dart';
import '../../auth/data/auth_notifier.dart';
import '../domain/financial_event.dart';

// ────────────────────────────────────────────────────────────────
// State
// ────────────────────────────────────────────────────────────────

class FinancialState {
  final List<FinancialEvent> events;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String filter; // 'all', 'pendiente', 'pagado'
  final bool hasChanges;

  const FinancialState({
    this.events = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.filter = 'all',
    this.hasChanges = false,
  });

  FinancialState copyWith({
    List<FinancialEvent>? events,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? filter,
    bool? hasChanges,
    bool clearError = false,
  }) {
    return FinancialState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }

  /// Eventos filtrados según [filter].
  List<FinancialEvent> get filteredEvents {
    if (filter == 'all') return events;
    final target = filter == 'pagado' ? 0 : 1;
    return events.where((e) => e.estado == target).toList();
  }
}

// ────────────────────────────────────────────────────────────────
// Notifier
// ────────────────────────────────────────────────────────────────

class FinancialNotifier extends StateNotifier<FinancialState> {
  final ApiClient _apiClient;
  final String _type; // 'comisiones' | 'propinas'
  String _dataHash = '';

  FinancialNotifier(this._apiClient, this._type) : super(const FinancialState());

  String get _endpoint =>
      _type == 'comisiones' ? '/commissions/user' : '/tips?tipo=detalle';

  Future<void> fetchEvents({bool isManual = false}) async {
    state = state.copyWith(isLoading: true, error: null, hasChanges: false);

    try {
      final response = await _apiClient.dio.get(_endpoint);
      final raw = response.data;

      List<dynamic> jsonList;
      if (raw is Map && raw['data'] != null) {
        jsonList = raw['data'] as List<dynamic>;
      } else if (raw is List) {
        jsonList = raw;
      } else {
        jsonList = [];
      }

      // Para comisiones filtrar solo tipo 'venta' (como en Expo)
      var items = jsonList
          .map((j) => FinancialEvent.fromJson(j as Map<String, dynamic>))
          .toList();

      if (_type == 'comisiones') {
        items = items.where((e) => e.tipo == 'venta').toList();
      }

      // Data hash para detectar cambios
      final serialized = items.map((e) => e.id).join(',');
      final hasChanges = _dataHash.isNotEmpty && _dataHash != serialized;
      _dataHash = serialized;

      state = state.copyWith(
        events: items,
        isLoading: false,
        isRefreshing: false,
        hasChanges: isManual && hasChanges,
      );

      if (isManual && hasChanges) {
        HapticFeedback.mediumImpact();
      }
    } catch (e, stack) {
      Logger.captureException(e, hint: 'fetchFinancialEvents', stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true);
    await fetchEvents(isManual: true);
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }
}

// ────────────────────────────────────────────────────────────────
// Provider
// ────────────────────────────────────────────────────────────────

final financialProvider =
    StateNotifierProvider.family<FinancialNotifier, FinancialState, String>(
  (ref, type) {
    final apiClient = ref.watch(apiClientProvider);
    return FinancialNotifier(apiClient, type);
  },
);
