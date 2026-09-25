import 'dart:async';

/// Canales de refresco equivalentes a los `REALTIME_EVENT_NAMES` de la app Expo
/// (`lasmunecasderamon-app/utils/realtime.ts`). Las pantallas se suscriben y
/// refrescan solo lo que les corresponde cuando el dispatcher SSE emite.
enum RefreshChannel {
  /// Home / dashboard por rol.
  dashboard,

  /// Solicitudes de servicio y pedidos (cajero).
  requests,

  /// Ventas.
  sales,

  /// Anticipos del usuario.
  anticipos,

  /// Cuentas.
  cuentas,

  /// Stock y transferencias del bar.
  bar,

  /// Catálogo de categorías (carritos y pantallas de venta).
  categories,

  /// Gratificaciones (administración).
  gratificaciones,

  /// Perfil del usuario.
  profile,

  /// Código de asistencia y escáner de personal (código nuevo / asistencia
  /// registrada por otra vía).
  attendanceCode,
}

/// Bus global tipo `eventBus` de la app Expo: stream broadcast estático al que
/// cualquier pantalla se suscribe y que solo el dispatcher SSE alimenta.
class RefreshBus {
  RefreshBus._();

  static final StreamController<RefreshChannel> _controller =
      StreamController<RefreshChannel>.broadcast();

  static Stream<RefreshChannel> get stream => _controller.stream;

  static void emit(RefreshChannel channel) {
    if (!_controller.isClosed) _controller.add(channel);
  }
}
