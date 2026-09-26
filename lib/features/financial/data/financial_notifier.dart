import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/api_client.dart';
import '../../../core/logger.dart';
import '../../auth/data/auth_notifier.dart';
import '../domain/financial_event.dart';





class FinancialState {
  final List<FinancialEvent> events;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String filter; 
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

  
  List<FinancialEvent> get filteredEvents {
    if (filter == 'all') return events;
    // Pendiente = estado 1. Pagado/cobrado es todo lo demás: 0 en propinas
    // (PayrollRepository) y 2 en comisiones (CommissionRepository). Filtrar
    // `estado == 0` dejaba fuera toda comisión pagada del chip «Pagado».
    if (filter == 'pendiente') {
      return events.where((e) => e.estado == 1).toList();
    }
    if (filter == 'pagado') {
      return events.where((e) => e.estado != 1).toList();
    }
    return events;
  }
}





class FinancialNotifier extends StateNotifier<FinancialState> {
  final ApiClient _apiClient;
  final String _type; 
  String _dataHash = '';

  FinancialNotifier(this._apiClient, this._type) : super(const FinancialState());

  // `?tipo=detalle` (paridad con Expo): filas por comisión — el default de
  // /commissions/user es la fila agregada por usuario y no trae `tipo`, con
  // lo que el filtro `tipo == 'venta'` descartaba todo y la lista quedaba vacía.
  String get _endpoint => _type == 'comisiones'
      ? '/commissions/user?tipo=detalle'
      : '/tips?tipo=detalle';

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

      
      var items = jsonList
          .map((j) => FinancialEvent.fromJson(j as Map<String, dynamic>))
          .toList();

      if (_type == 'comisiones') {
        items = items.where((e) => e.tipo == 'venta').toList();
      }

      
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





final financialProvider =
    StateNotifierProvider.family<FinancialNotifier, FinancialState, String>(
  (ref, type) {
    final apiClient = ref.watch(apiClientProvider);
    return FinancialNotifier(apiClient, type);
  },
);
