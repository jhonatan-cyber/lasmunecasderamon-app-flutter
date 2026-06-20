import 'package:dio/dio.dart';
import 'offline_sync_manager.dart';








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
