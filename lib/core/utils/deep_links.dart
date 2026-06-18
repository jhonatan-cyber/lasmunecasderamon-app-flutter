import 'package:flutter/foundation.dart';

/// Deep-link route definitions matching the app's routing structure.
///
/// Mirrors Expo's `utils/deepLinks.ts` — maps notification types and
/// external URLs to in-app navigation routes.
class DeepLinks {
  // ── Screen paths ──────────────────────────────────────────────────────

  static const String login = '/login';
  static const String garzonHome = '/garzon';
  static const String cajeroHome = '/cajero';
  static const String anfitrionaHome = '/anfitriona';
  static const String perfil = '/garzon/perfil';

  // ── Path builders ──────────────────────────────────────────────────────

  /// Builds a route path for notification-based deep linking.
  ///
  /// Supports paths like:
  /// - `servicio/{id}` → `/cajero/servicios`
  /// - `venta/{id}` → `/cajero/ventas`
  /// - `solicitud/{id}` → `/cajero/solicitudes`
  /// - `anticipo/{id}` → `/garzon/anticipos` (role-dependent)
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

  /// Parses an external URL and returns the corresponding in-app route.
  ///
  /// Supports URLs like:
  /// - `lasmunecasderamon://servicio/{id}`
  /// - `lasmunecasderamon://venta/{id}`
  /// - `https://lasmunecasderamon.app/servicio/{id}`
  static String fromExternalUrl(Uri uri) {
    // Custom scheme: lasmunecasderamon://{path}
    if (uri.scheme == 'lasmunecasderamon') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final type = segments.first;
        return fromNotificationType(type, segments.length > 1 ? segments[1] : null);
      }
    }

    // Web URL: https://lasmunecasderamon.app/{path}
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
