import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';





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





class VentasListNotifier extends StateNotifier<VentasListState> {
  final ApiClient _apiClient;

  VentasListNotifier(this._apiClient) : super(VentasListState());

  
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

  
  Future<void> fetchDetail(String ventaId) async {
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

  
  /// Finaliza una venta en proceso (estado 1). Al fallar deja el motivo en
  /// `state.error` (mensaje del backend si existe) para que la UI lo muestre
  /// en vez de un genérico sin causa.
  Future<bool> finalizarVenta(String ventaId) async {
    if (!mounted) return false;
    state = state.copyWith(clearError: true);

    try {
      final response = await _apiClient.dio.patch(
        '/ventas/$ventaId',
        data: {'estado': 1},
      );

      if (response.data != null && response.data['success'] == true) {
        _updateLocalEstado(ventaId, 1);
        await _refreshResumen();
        return true;
      }

      if (!mounted) return false;
      state = state.copyWith(
        error: _serverMessage(response.data) ?? 'No se pudo finalizar la venta',
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      final serverMessage = e is DioException ? _serverMessage(e.response?.data) : null;
      state = state.copyWith(
        error: serverMessage ?? 'Error al finalizar la venta',
      );
      return false;
    }
  }

  /// Extrae `message` de una respuesta del backend cuando la trae.
  String? _serverMessage(dynamic data) {
    if (data is Map && data['message']?.toString().isNotEmpty == true) {
      return data['message'].toString();
    }
    return null;
  }

  /// Refresca solo el resumen tras finalizar: el total del día lo calcula el
  /// backend y ajustarlo localmente podía desviarse del real.
  Future<void> _refreshResumen() async {
    try {
      final response = await _apiClient.dio.get('/sales?tipo=resumen');
      if (!mounted) return;
      if (response.data != null && response.data['success'] == true) {
        state = state.copyWith(
          resumen: Map<String, dynamic>.from(response.data['data'] ?? {}),
        );
      }
    } catch (_) {
      // Sin conexión se conserva el último resumen conocido.
    }
  }

  
  Future<bool> anularVenta(String ventaId, String motivo, double monto) async {
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

  

  void _updateLocalEstado(String ventaId, int newEstado) {
    final updated = state.ventas.map((v) {
      final id = v['id_venta']?.toString() ?? '';
      if (id == ventaId) {
        return {...Map<String, dynamic>.from(v), 'estado': newEstado};
      }
      return v;
    }).toList();

    // El detalle abierto no debe quedar con el estado viejo.
    final selected = state.selectedVenta;
    dynamic updatedSelected = selected;
    if (selected != null &&
        (selected['id_venta']?.toString() ?? '') == ventaId) {
      updatedSelected = {
        ...Map<String, dynamic>.from(selected),
        'estado': newEstado,
      };
    }

    state = state.copyWith(ventas: updated, selectedVenta: updatedSelected);
  }
}





final ventasListProvider =
    StateNotifierProvider.autoDispose<VentasListNotifier, VentasListState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return VentasListNotifier(apiClient);
});
