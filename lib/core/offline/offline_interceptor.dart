import 'package:dio/dio.dart';
import 'offline_sync_manager.dart';

/// Dio interceptor that queues failed requests when the device is offline.
///
/// - On **connection errors** (`connectionError`, `connectionTimeout`,
///   `sendTimeout`) it serialises the failed request into the offline queue
///   and lets the error propagate so the caller still sees the failure.
/// - Only mutating requests (POST, PUT, PATCH, DELETE) are queued — GET
///   requests are served from cache by `DioCacheInterceptor`.
class OfflineInterceptor extends Interceptor {
  final OfflineSyncManager _syncManager;

  OfflineInterceptor(this._syncManager);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isConnectionError = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout;

    if (isConnectionError && _isMutatingMethod(err.requestOptions.method)) {
      _syncManager.queueRequestFromOptions(err.requestOptions);
    }

    handler.next(err);
  }

  bool _isMutatingMethod(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
      case 'PUT':
      case 'PATCH':
      case 'DELETE':
        return true;
      default:
        return false;
    }
  }
}
