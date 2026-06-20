import 'package:flutter/foundation.dart';





class DeepLinks {
  

  static const String login = '/login';
  static const String garzonHome = '/garzon';
  static const String cajeroHome = '/cajero';
  static const String anfitrionaHome = '/anfitriona';
  static const String perfil = '/garzon/perfil';

  

  
  
  
  
  
  
  
  static String fromNotificationType(String type, String? id, {String? role}) {
    switch (type) {
      case 'servicio':
      case 'service':
        final base = role == 'cajero' ? '/cajero' : '/garzon';
        return '$base/servicios';
      case 'venta':
      case 'sale':
        return '/cajero/ventas';
      case 'solicitud':
      case 'request':
        return '/cajero/solicitudes';
      case 'anticipo':
      case 'advance':
        final base = role == 'cajero' ? '/cajero' : '/garzon';
        return '$base/anticipos';
      case 'cuenta':
      case 'bill':
        return '/cajero/cuentas';
      default:
        if (kDebugMode) debugPrint('DeepLinks: unknown notification type "$type"');
        return '/';
    }
  }

  
  
  
  
  
  
  static String fromExternalUrl(Uri uri) {
    
    if (uri.scheme == 'lasmunecasderamon') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final type = segments.first;
        return fromNotificationType(type, segments.length > 1 ? segments[1] : null);
      }
    }

    
    if (uri.host.contains('lasmunecasderamon')) {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        switch (segments.first) {
          case 'reset-password':
            return '/auth/reset-password';
          case 'verify':
            return '/verify-code';
          default:
            return fromNotificationType(segments.first,
                segments.length > 1 ? segments[1] : null);
        }
      }
    }

    return '/';
  }
}
