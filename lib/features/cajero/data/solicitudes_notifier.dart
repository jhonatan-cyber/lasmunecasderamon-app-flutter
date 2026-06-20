import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';
import 'solicitud_item.dart';





class SolicitudesListState {
  final bool isLoading;
  final bool isRefreshing;
  final String error;
  final List<SolicitudItem> solicitudes;
  final List<dynamic> allHostesses;
  final bool cajaAbierta;

  SolicitudesListState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error = '',
    this.solicitudes = const [],
    this.allHostesses = const [],
    this.cajaAbierta = false,
  });

  SolicitudesListState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<SolicitudItem>? solicitudes,
    List<dynamic>? allHostesses,
    bool? cajaAbierta,
    bool clearError = false,
  }) {
    return SolicitudesListState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? '' : (error ?? this.error),
      solicitudes: solicitudes ?? this.solicitudes,
      allHostesses: allHostesses ?? this.allHostesses,
      cajaAbierta: cajaAbierta ?? this.cajaAbierta,
    );
  }
}





class SolicitudesListNotifier extends StateNotifier<SolicitudesListState> {
  final ApiClient _apiClient;

  SolicitudesListNotifier(this._apiClient) : super(SolicitudesListState());

  Future<void> _handleDioError(dynamic e) {
    if (e is DioException) {
      state = state.copyWith(error: 'Error de conexión');
    } else {
      state = state.copyWith(error: 'Error inesperado');
    }
    return Future.value();
  }

  
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
            .get('/solicitudes-servicios?estado=0')
            .catchError((_) => Response(
                  requestOptions: RequestOptions(),
                  data: {'success': false, 'data': []},
                )),
        _apiClient.dio
            .get('/orders')
            .catchError((_) => Response(
                  requestOptions: RequestOptions(),
                  data: {'success': false, 'data': []},
                )),
        _apiClient.dio
            .get('/anticipos')
            .catchError((_) => Response(
                  requestOptions: RequestOptions(),
                  data: {'success': false, 'data': []},
                )),
        _apiClient.dio
            .get('/caja/stats')
            .catchError((_) => Response(
                  requestOptions: RequestOptions(),
                  data: {'success': false, 'cajas_abiertas': 0},
                )),
        _apiClient.dio
            .get('/anfitrionas')
            .catchError((_) => Response(
                  requestOptions: RequestOptions(),
                  data: {'success': false, 'data': []},
                )),
      ]);

      if (!mounted) return;

      final resServices = responses[0];
      final resOrders = responses[1];
      final resAdvances = responses[2];
      final resCaja = responses[3];
      final resHostesses = responses[4];

      
      List<dynamic> hostesses = [];
      if (resHostesses.data != null) {
        final hostList = resHostesses.data['success'] == true
            ? resHostesses.data['data']
            : resHostesses.data;
        if (hostList is List) {
          hostesses = hostList;
        }
      }

      
      bool cajaAbierta = false;
      if (resCaja.data != null &&
          resCaja.data['cajas_abiertas'] != null) {
        cajaAbierta =
            (int.tryParse(resCaja.data['cajas_abiertas'].toString()) ?? 0) > 0;
      }

      
      List<SolicitudItem> combined = [];

      if (resServices.data != null &&
          resServices.data['success'] == true) {
        final list = resServices.data['data'];
        if (list is List) {
          combined.addAll(list.map((s) => SolicitudItem.fromService(s)));
        }
      }

      if (resOrders.data != null && resOrders.data['success'] == true) {
        final list = resOrders.data['data'];
        if (list is List) {
          combined.addAll(list.map((o) => SolicitudItem.fromOrder(o)));
        }
      }

      if (resAdvances.data != null && resAdvances.data['success'] == true) {
        final list = resAdvances.data['data'];
        if (list is List) {
          final filtered = list.where((a) {
            final st = int.tryParse(a['estado']?.toString() ?? '0') ?? 0;
            return st == 1 || st == 2;
          });
          combined.addAll(
            filtered.map((a) => SolicitudItem.fromAnticipo(a)),
          );
        }
      }

      
      combined.sort((a, b) => b.fechaOrden.compareTo(a.fechaOrden));

      state = state.copyWith(
        solicitudes: combined,
        allHostesses: hostesses,
        cajaAbierta: cajaAbierta,
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      if (!mounted) return;
      await _handleDioError(e);
      state = state.copyWith(isLoading: false, isRefreshing: false);
    }
  }

  
  Future<bool> aprobarAnticipo(SolicitudItem item) async {
    try {
      
      if (item.estado == 2) {
        final approveRes = await _apiClient.dio.put(
          '/anticipos/${item.id}',
          data: {'estado': 1},
        );
        if (approveRes.data == null ||
            approveRes.data['success'] != true) {
          return false;
        }
      }

      
      final payRes = await _apiClient.dio.put(
        '/anticipos/${item.id}',
        data: {'estado': 0},
      );

      if (payRes.data != null && payRes.data['success'] == true) {
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  
  Future<bool> rechazarSolicitud(SolicitudItem item) async {
    try {
      final isSrv = item.tipoItem == 'solicitud';
      final endpoint = isSrv
          ? '/solicitudes-servicios/${item.id}/rechazar'
          : '/orders/${item.id}';

      final response = isSrv
          ? await _apiClient.dio.patch(
              endpoint,
              data: {'motivo_rechazo': 'Rechazado por Caja'},
            )
          : await _apiClient.dio.put(
              endpoint,
              data: {'estado': 2},
            );

      if (response.data != null && response.data['success'] == true) {
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}





final solicitudesListProvider =
    StateNotifierProvider.autoDispose<SolicitudesListNotifier, SolicitudesListState>(
  (ref) {
    final apiClient = ref.read(apiClientProvider);
    return SolicitudesListNotifier(apiClient);
  },
);
