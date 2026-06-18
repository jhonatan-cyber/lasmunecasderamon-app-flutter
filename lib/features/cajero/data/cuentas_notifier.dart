import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class CuentasListState {
  final bool isLoading;
  final bool isRefreshing;
  final String error;
  final List<dynamic> cuentas;
  final Map<String, dynamic> resumen;

  CuentasListState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error = '',
    this.cuentas = const [],
    this.resumen = const {},
  });

  CuentasListState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<dynamic>? cuentas,
    Map<String, dynamic>? resumen,
    bool clearError = false,
  }) {
    return CuentasListState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? '' : (error ?? this.error),
      cuentas: cuentas ?? this.cuentas,
      resumen: resumen ?? this.resumen,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class CuentasListNotifier extends StateNotifier<CuentasListState> {
  final ApiClient _apiClient;

  CuentasListNotifier(this._apiClient) : super(CuentasListState());

  /// Fetch accounts list + summary in parallel.
  Future<void> fetchData({bool isManual = false}) async {
    if (!mounted) return;
    state = state.copyWith(
      isRefreshing: isManual,
      isLoading: !isManual,
      clearError: true,
    );

    try {
      final responses = await Future.wait([
        _apiClient.dio.get('/cuentas?limit=50'),
        _apiClient.dio.get('/cuentas?tipo=resumen'),
      ]);

      final accountsRes = responses[0];
      final summaryRes = responses[1];

      if (!mounted) return;

      List<dynamic> cuentas = [];
      if (accountsRes.data != null && accountsRes.data['success'] == true) {
        cuentas = List<dynamic>.from(accountsRes.data['data'] ?? []);
      }

      Map<String, dynamic> resumen = {};
      if (summaryRes.data != null && summaryRes.data['success'] == true) {
        resumen = Map<String, dynamic>.from(summaryRes.data['data'] ?? {});
      }

      state = state.copyWith(
        cuentas: cuentas,
        resumen: resumen,
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Error al cargar las cuentas activas',
      );
    }
  }

  /// Stop timer for a cuenta.
  Future<bool> detenerTiempo(int idCuenta) async {
    try {
      final response = await _apiClient.dio.post('/cuentas/$idCuenta/stop');
      if (response.data != null && response.data['success'] == true) {
        // Re-fetch to get updated data
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cobrar / facturar una cuenta.
  Future<bool> cobrarCuenta({
    required int idCuenta,
    required String metodoPago,
    required double propina,
    required double cargoTarjeta,
    required int usuarioId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/cuentas/$idCuenta/cobrar',
        data: {
          'metodo_pago': metodoPago,
          'propina': propina,
          'cargo_tarjeta': cargoTarjeta,
          'usuario_id': usuarioId,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        // Remove cuenta locally optimistically
        _removeLocalCuenta(idCuenta);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Anular una cuenta.
  Future<bool> anularCuenta(int idCuenta, String motivo) async {
    try {
      final response = await _apiClient.dio.post(
        '/cuentas/anulacion',
        data: {'id_cuenta': idCuenta, 'motivo': motivo},
      );

      if (response.data != null && response.data['success'] == true) {
        // Remove cuenta locally optimistically
        _removeLocalCuenta(idCuenta);
        return true;
      }
      final msg = response.data?['message'] ?? 'Error al anular cuenta';
      state = state.copyWith(error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Error de conexión al anular cuenta');
      return false;
    }
  }

  // ── Helpers ──

  void _removeLocalCuenta(int idCuenta) {
    final updated = state.cuentas.where((c) {
      final id = int.tryParse(c['id_cuenta']?.toString() ?? '') ??
          int.tryParse(c['id']?.toString() ?? '');
      return id != idCuenta;
    }).toList();
    state = state.copyWith(cuentas: updated);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final cuentasListProvider =
    StateNotifierProvider.autoDispose<CuentasListNotifier, CuentasListState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return CuentasListNotifier(apiClient);
});
