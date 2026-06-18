import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class VentasListState {
  final bool isLoading;
  final bool isRefreshing;
  final bool loadingDetail;
  final bool anulandoVenta;
  final String error;
  final List<dynamic> ventas;
  final Map<String, dynamic> resumen;
  final dynamic selectedVenta;

  VentasListState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.loadingDetail = false,
    this.anulandoVenta = false,
    this.error = '',
    this.ventas = const [],
    this.resumen = const {},
    this.selectedVenta,
  });

  VentasListState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? loadingDetail,
    bool? anulandoVenta,
    String? error,
    List<dynamic>? ventas,
    Map<String, dynamic>? resumen,
    dynamic selectedVenta,
    bool clearError = false,
  }) {
    return VentasListState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadingDetail: loadingDetail ?? this.loadingDetail,
      anulandoVenta: anulandoVenta ?? this.anulandoVenta,
      error: clearError ? '' : (error ?? this.error),
      ventas: ventas ?? this.ventas,
      resumen: resumen ?? this.resumen,
      selectedVenta: selectedVenta ?? this.selectedVenta,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class VentasListNotifier extends StateNotifier<VentasListState> {
  final ApiClient _apiClient;

  VentasListNotifier(this._apiClient) : super(VentasListState());

  /// Fetch sales list + summary in parallel.
  Future<void> fetchData({bool isManual = false}) async {
    if (!mounted) return;
    state = state.copyWith(
      isRefreshing: isManual,
      isLoading: !isManual,
      clearError: true,
    );

    try {
      final responses = await Future.wait([
        _apiClient.dio
            .get('/sales?limit=50')
            .catchError(
              (_) => throw Exception('Error al cargar ventas'),
            ),
        _apiClient.dio
            .get('/sales?tipo=resumen')
            .catchError(
              (_) => throw Exception('Error al cargar resumen'),
            ),
      ]);

      final salesRes = responses[0];
      final summaryRes = responses[1];

      if (!mounted) return;

      List<dynamic> ventas = [];
      if (salesRes.data != null && salesRes.data['success'] == true) {
        ventas = List<dynamic>.from(salesRes.data['data'] ?? []);
      }

      Map<String, dynamic> resumen = {};
      if (summaryRes.data != null && summaryRes.data['success'] == true) {
        resumen = Map<String, dynamic>.from(summaryRes.data['data'] ?? {});
      }

      state = state.copyWith(
        ventas: ventas,
        resumen: resumen,
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Error de conexión al cargar ventas',
      );
    }
  }

  /// Fetch detail for a single venta.
  Future<void> fetchDetail(int ventaId) async {
    state = state.copyWith(loadingDetail: true, clearError: true);

    try {
      final response = await _apiClient.dio.get('/ventas/$ventaId');
      if (!mounted) return;

      if (response.data != null && response.data['success'] == true) {
        state = state.copyWith(
          selectedVenta: response.data['data'],
          loadingDetail: false,
        );
      } else {
        state = state.copyWith(
          loadingDetail: false,
          error: 'No se pudo cargar el detalle',
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loadingDetail: false,
        error: 'Error al cargar detalle de la venta',
      );
    }
  }

  /// Finalizar a venta (estado = 1).
  Future<bool> finalizarVenta(int ventaId) async {
    try {
      final response = await _apiClient.dio.put(
        '/ventas/$ventaId',
        data: {'estado': 1},
      );

      if (response.data != null && response.data['success'] == true) {
        // Update the venta locally to reflect estado=1
        _updateLocalEstado(ventaId, 1);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Solicitar anulación de una venta.
  Future<bool> anularVenta(int ventaId, String motivo, double monto) async {
    state = state.copyWith(anulandoVenta: true, clearError: true);

    try {
      final response = await _apiClient.dio.post(
        '/ventas/anulacion',
        data: {'ventaId': ventaId, 'motivo': motivo, 'monto': monto},
      );

      if (!mounted) return false;

      if (response.data != null && response.data['success'] == true) {
        state = state.copyWith(anulandoVenta: false);
        return true;
      }

      state = state.copyWith(
        anulandoVenta: false,
        error: response.data?['message'] ?? 'No se pudo solicitar la anulación',
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        anulandoVenta: false,
        error: 'Error al procesar la solicitud de anulación',
      );
      return false;
    }
  }

  /// Reset selected venta (close detail modal).
  void clearSelectedVenta() {
    state = VentasListState(
      isLoading: state.isLoading,
      isRefreshing: state.isRefreshing,
      loadingDetail: false,
      anulandoVenta: state.anulandoVenta,
      error: state.error,
      ventas: state.ventas,
      resumen: state.resumen,
      selectedVenta: null,
    );
  }

  // ── Helpers ──

  void _updateLocalEstado(int ventaId, int newEstado) {
    final updated = state.ventas.map((v) {
      final id = int.tryParse(v['id_venta']?.toString() ?? '');
      if (id == ventaId) {
        return {...v as Map<String, dynamic>, 'estado': newEstado};
      }
      return v;
    }).toList();
    state = state.copyWith(ventas: updated);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final ventasListProvider =
    StateNotifierProvider.autoDispose<VentasListNotifier, VentasListState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return VentasListNotifier(apiClient);
});
