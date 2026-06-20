import 'package:sentry_flutter/sentry_flutter.dart';












class Logger {
  Logger._();

  

  static void debug(String message, {String? hint, Object? data}) {
    _log('DEBUG', message, hint, data);
    _addBreadcrumb('debug', message, data);
  }

  static void info(String message, {String? hint, Object? data}) {
    _log('INFO', message, hint, data);
    _addBreadcrumb('info', message, data);
  }

  static void warn(String message, {String? hint, Object? data}) {
    _log('WARN', message, hint, data);
    _addBreadcrumb('warning', message, data);
  }

  static void error(String message, {String? hint, Object? data}) {
    _log('ERROR', message, hint, data);
    _addBreadcrumb('error', message, data);
  }

  
  
  
  
  static Future<void> captureException(
    Object error, {
    String? hint,
    Object? data,
    StackTrace? stackTrace,
  }) async {
    _log('CAPTURE', '${error.runtimeType}: $error', hint, data);

    await Sentry.captureException(
      error,
      stackTrace: stackTrace ?? StackTrace.current,
      withScope: (scope) {
        if (hint != null) scope.setTag('context', hint);
        if (data != null) {
          scope.setContexts('extra', {'data': data.toString()});
        }
      },
    );
  }

  

  static void _log(String level, String message, String? hint, Object? data) {
    // ignore: avoid_print
    print('[${DateTime.now().toIso8601String()}] [$level]${hint != null ? ' ($hint)' : ''} $message${data != null ? ' | $data' : ''}');
  }

  static void _addBreadcrumb(String category, String message, Object? data) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category,
        data: data is Map<String, dynamic>
            ? data.cast<String, dynamic>()
            : data != null
                ? {'value': data.toString()}
                : null,
      ));
    } catch (_) {
      
    }
  }
}
