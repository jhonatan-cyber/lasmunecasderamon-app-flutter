import 'package:dio/dio.dart';

import 'api_client.dart';

/// Parsea `GET /cashregister/status`: `true`/`false` cuando el backend lo
/// confirma y `null` cuando no se pudo determinar (un estado desconocido no
/// debe bloquear movimientos, igual que en el dashboard).
bool? parseCajaAbierta(Response response) {
  final dynamic body = response.data;
  if (body is Map && body['success'] == true && body['data'] is Map) {
    return body['data']['hasOpenCaja'] == true;
  }
  return null;
}

/// Consulta puntual del estado de caja: un solo GET, no recarga catálogos,
/// clientes ni carrito. Devuelve `null` si la petición falla.
Future<bool?> fetchCajaAbierta(ApiClient client) async {
  try {
    final response = await client.dio.get('/cashregister/status');
    return parseCajaAbierta(response);
  } catch (_) {
    return null;
  }
}
