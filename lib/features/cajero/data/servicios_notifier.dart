import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class ServiciosListState {
  final bool isLoading;
  final bool isRefreshing;
  final String error;
  final List<dynamic> servicios;

  ServiciosListState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error = '',
    this.servicios = const [],
  });

  ServiciosListState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<dynamic>? servicios,
    bool clearError = false,
  }) {
    return ServiciosListState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? '' : (error ?? this.error),
      servicios: servicios ?? this.servicios,
    );
  }

  /// Servicios con estado = 0 (en curso)
  List<dynamic> get activeServicios {
    return servicios
        .where((s) => (int.tryParse(s['estado']?.toString() ?? '0') ?? 0) == 0)
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ServiciosListNotifier extends StateNotifier<ServiciosListState> {
  final ApiClient _apiClient;

  ServiciosListNotifier(this._apiClient) : super(ServiciosListState(isLoading: true));

  // ── Fetch ────────────────────────────────────────────────────────────────

  Future<void> fetchServicios({bool isManual = false}) async {
    state = state.copyWith(
      isLoading: !isManual,
      isRefreshing: isManual,
      clearError: true,
    );

    try {
      final response = await _apiClient.dio.get('/servicios?all=true');

      if (response.data != null && response.data['success'] == true) {
        state = state.copyWith(
          servicios: response.data['data'] ?? [],
          isLoading: false,
          isRefreshing: false,
        );
      } else {
        state = state.copyWith(
          error: 'Error al cargar los servicios',
          isLoading: false,
          isRefreshing: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Error de conexión al cargar servicios',
        isLoading: false,
        isRefreshing: false,
      );
    }
  }

  // ── Finalizar ────────────────────────────────────────────────────────────

  Future<bool> finalizarServicio(int idServicio) async {
    try {
      final response = await _apiClient.dio.patch(
        '/servicios/$idServicio',
        data: {'estado': 1},
      );

      if (response.data != null && response.data['success'] == true) {
        // Remove from local state optimistically
        state = state.copyWith(
          servicios: [
            for (final s in state.servicios)
              if ((int.tryParse(s['id_servicio']?.toString() ?? s['id']?.toString() ?? '0') ?? 0) != idServicio)
                s,
          ],
        );
        return true;
      } else {
        state = state.copyWith(
          error: response.data?['message'] ?? 'Error al finalizar servicio',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Error de conexión al finalizar servicio',
      );
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final serviciosListProvider =
    StateNotifierProvider.autoDispose<ServiciosListNotifier, ServiciosListState>(
  (ref) {
    final apiClient = ref.watch(apiClientProvider);
    return ServiciosListNotifier(apiClient);
  },
);
