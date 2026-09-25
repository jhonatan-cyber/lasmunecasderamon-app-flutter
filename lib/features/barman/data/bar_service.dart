import 'package:dio/dio.dart';

/// Endpoints del rol Barman, espejo de `services/bar.ts` de la app Expo:
/// stock del bar, movimientos, transferencias almacén→bar y el control de
/// envases (entrega del bar al almacén, paso 1 del circuito).
class BarService {
  BarService(this._dio);

  final Dio _dio;

  /// Stock del bar (`GET /bar`): presentaciones traspasadas por el almacén.
  Future<List<dynamic>> stock() async {
    final res = await _dio.get('/bar');
    return _listOf(res.data);
  }

  /// Últimos movimientos del bar (`GET /bar/movements?limit=`).
  Future<List<dynamic>> movements({int limit = 100}) async {
    final res = await _dio.get('/bar/movements?limit=$limit');
    return _listOf(res.data);
  }

  /// Historial de envases entregados por el bar (`GET /bar/containers`).
  Future<List<dynamic>> containers() async {
    final res = await _dio.get('/bar/containers');
    return _listOf(res.data);
  }

  /// Contador del control de envases (`GET /bar/containers/summary`):
  /// entregados pendientes de recepción + atrasados.
  Future<Map<String, dynamic>?> containerSummary() async {
    final res = await _dio.get('/bar/containers/summary');
    final data = res.data;
    if (data is Map && data['data'] is Map) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  }

  /// Paso 1 del control de envases: verifica el código escaneado y lo marca
  /// como entregado. `data.ok == false` trae `motivo` (ver [motivoEnvase]).
  Future<Map<String, dynamic>> returnContainer(String codigo) async {
    final res = await _dio.post('/bar/containers', data: {'codigo': codigo});
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      return (body['data'] as Map).cast<String, dynamic>();
    }
    throw Exception(
        body is Map && body['message'] != null ? body['message'] : 'Respuesta inesperada del servidor');
  }

  /// Transferencias pendientes de aceptación (`GET /transfers/pending`).
  Future<List<dynamic>> pendingTransfers() async {
    final res = await _dio.get('/transfers/pending');
    return _listOf(res.data);
  }

  /// Acepta la transferencia (`POST /transfers/{id}/accept`).
  Future<void> acceptTransfer(String id) async {
    await _dio.post('/transfers/$id/accept');
  }

  /// Rechaza la transferencia (`PATCH /transfers` con accion=rechazar).
  Future<void> rejectTransfer(String id) async {
    await _dio.patch('/transfers', data: {'id': id, 'accion': 'rechazar'});
  }

  static List<dynamic> _listOf(dynamic body) {
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is Map && body['data'] is Map && body['data']['data'] is List) {
      return body['data']['data'] as List;
    }
    return const [];
  }
}

/// Texto corto del motivo por el que un escaneo no se aceptó. Espejo de
/// `MOTIVO_ENVASE` del dashboard y de `useEnvasesScreen.ts` de la app Expo.
const Map<String, String> motivoEnvase = {
  'no_es_nuestro': 'No es nuestro',
  'no_esta_vacia': 'No está vacío',
  'ya_devuelto': 'Ya entregado',
  'no_entregado': 'El bar no lo entregó',
  'ya_confirmado': 'Ya confirmado',
};
