import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_notifier.dart';
import 'global_messenger.dart';
import 'haptic_service.dart';
import 'push_notification_service.dart';
import 'refresh_bus.dart';
import 'sse_event.dart';
import 'sse_service.dart';

/// Dispatcher global de eventos SSE.
///
/// Es el equivalente a `context/NotificationContext.tsx` de la app Expo: un único
/// listener que recibe los 36 eventos del catálogo
/// (`lasmunecasderamon-dashboard/lib/api/sseEvents.ts`) y aplica los efectos
/// secundarios — toasts, notificaciones locales, refrescos por pantalla, cierre
/// de sesión — sin que cada pantalla tenga que suscribirse al stream.
///
/// Eventos que *no* gestiona acá porque ya tienen dueño:
///  - `timer_*` / `timers_updated` → `timerProvider`
///  - `staff_call`, `staff_call_accepted`, `assistance_request` → `staff_call_overlay`
class SseDispatcher {
  SseDispatcher(this._ref);

  final Ref _ref;

  static const Set<String> _controlEvents = {'connected', 'ping'};

  void handle(SseEvent event) {
    final type = event.type;
    if (_controlEvents.contains(type)) return;

    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final data = event.data;
    final role = user.role.trim().toLowerCase();
    final isCajeroOrAdmin = user.isCajeroOrAdmin;
    final isRequester =
        data['usuario_id'] != null && data['usuario_id'].toString() == user.id;

    switch (type) {
      // ─── Operativos: pedidos y solicitudes (cajero / administración) ────
      case 'new_order':
      case 'new_service_request':
        if (!isCajeroOrAdmin) break;
        final isOrder = type == 'new_order';
        final body = isOrder
            ? '${data['codigo'] ?? ''} - ${data['cliente'] ?? ''}'
            : 'ID: ${data['id'] ?? data['id_solicitud'] ?? ''} - ${data['descripcion'] ?? 'Sin descripción'}';
        HapticService.heavy();
        GlobalToast.show(
          title: isOrder ? '¡Nuevo Pedido!' : 'Solicitud de Servicio',
          body: body,
          kind: GlobalToastKind.info,
          duration: const Duration(seconds: 6),
        );
        showLocalNotification(
            isOrder ? 'Nuevo Pedido' : 'Solicitud de Servicio', body);
        RefreshBus.emit(RefreshChannel.requests);
        RefreshBus.emit(RefreshChannel.dashboard);
        break;

      case 'new_anticipo_request':
        if (!isCajeroOrAdmin) break;
        HapticService.medium();
        GlobalToast.show(
          title: 'Nueva solicitud de anticipo',
          body:
              '${data['nick'] ?? data['empleado'] ?? 'Empleado'} solicito un anticipo por ${_money(data['monto'])}',
          kind: GlobalToastKind.info,
          duration: const Duration(seconds: 5),
        );
        showLocalNotification('Nueva solicitud de anticipo',
            '${data['nick'] ?? data['empleado'] ?? 'Empleado'} solicito un anticipo por ${_money(data['monto'])}');
        RefreshBus.emit(RefreshChannel.requests);
        break;

      case 'ANTICIPO_PROCESSED':
      case 'anticipo_processed':
        final approved = data['status'] == 'approved' ||
            (num.tryParse('${data['estado']}') ?? 0) == 1;
        final who = data['nick'] ?? data['empleado'] ?? data['usuario'] ?? 'Empleado';
        final body = '$who - ${_money(data['monto'])}';
        if (isCajeroOrAdmin || isRequester) {
          HapticService.trigger(approved ? 'light' : 'medium');
          GlobalToast.show(
            title: approved ? 'Anticipo aceptado' : 'Anticipo rechazado',
            body: body,
            kind: approved ? GlobalToastKind.success : GlobalToastKind.error,
            duration: const Duration(seconds: 5),
          );
          showLocalNotification(
              approved ? 'Anticipo aceptado' : 'Anticipo rechazado', body);
        }
        if (isCajeroOrAdmin) RefreshBus.emit(RefreshChannel.requests);
        if (isRequester) RefreshBus.emit(RefreshChannel.anticipos);
        break;

      case 'anticipo_delivered':
        if (isCajeroOrAdmin || isRequester) {
          final body =
              '${data['nick'] ?? data['empleado'] ?? 'Empleado'} - ${_money(data['monto'])}';
          HapticService.light();
          GlobalToast.show(
            title: 'Anticipo entregado',
            body: body,
            kind: GlobalToastKind.success,
            duration: const Duration(seconds: 5),
          );
          showLocalNotification('Anticipo entregado', body);
        }
        if (isCajeroOrAdmin) RefreshBus.emit(RefreshChannel.requests);
        if (isRequester) RefreshBus.emit(RefreshChannel.anticipos);
        break;

      // ─── Temporizadores: los consume timerProvider; acá solo refrescos ────
      case 'timer_started':
      case 'timer_stopped':
        RefreshBus.emit(RefreshChannel.sales);
        RefreshBus.emit(RefreshChannel.requests);
        RefreshBus.emit(RefreshChannel.cuentas);
        break;
      case 'timer_updated':
      case 'timers_updated':
      case 'timer_warning_5m':
      case 'timer_ended_event':
      case 'room_available':
        RefreshBus.emit(RefreshChannel.dashboard);
        break;

      // ─── Ventas ─────────────────────────────────────────────────────────
      case 'updateSales':
      case 'sale_cancelled':
        if (!isCajeroOrAdmin) break;
        if (type == 'sale_cancelled') {
          GlobalToast.show(
            title: 'Venta Anulada',
            body: 'Total: ${_money(data['total'])}',
            kind: GlobalToastKind.success,
            duration: const Duration(seconds: 4),
          );
        }
        RefreshBus.emit(RefreshChannel.sales);
        RefreshBus.emit(RefreshChannel.requests);
        break;

      case 'order_deleted':
      case 'order_updated':
      case 'service_request_processed':
      case 'service_request_deleted':
        if (isCajeroOrAdmin) RefreshBus.emit(RefreshChannel.requests);
        RefreshBus.emit(RefreshChannel.dashboard);
        break;

      case 'service_changed':
        RefreshBus.emit(RefreshChannel.dashboard);
        break;

      // ─── Anulaciones de cuentas y ventas ────────────────────────────────
      case 'anulacion_processed':
        if (!isCajeroOrAdmin) break;
        final approved = data['accion'] == 'confirmar';
        final body =
            '${data['codigo'] ?? 'N/A'} - ${data['clienteNombre'] ?? 'Sin cliente'}';
        HapticService.trigger(approved ? 'light' : 'medium');
        GlobalToast.show(
          title: approved ? 'Solicitud aprobada' : 'Solicitud rechazada',
          body: body,
          kind: approved ? GlobalToastKind.success : GlobalToastKind.error,
          duration: const Duration(seconds: 5),
        );
        showLocalNotification(
            approved ? 'Solicitud aprobada' : 'Solicitud rechazada', body);
        RefreshBus.emit(RefreshChannel.requests);
        if (data['tipo'] == 'cuenta') {
          RefreshBus.emit(RefreshChannel.cuentas);
        } else if (data['tipo'] == 'venta') {
          RefreshBus.emit(RefreshChannel.sales);
        }
        break;

      // ─── Bar y almacén ──────────────────────────────────────────────────
      case 'bar_shot_alert':
        final alertas = data['alertas'] is List ? data['alertas'] as List : const [];
        final nombres = alertas
            .map((a) => a is Map ? a['nombre'] : null)
            .where((n) => n != null && '$n'.isNotEmpty)
            .take(2)
            .join(', ');
        final body = data['mensaje'] ??
            (nombres.isNotEmpty ? 'Por agotarse: $nombres' : 'Revisa el stock del bar');
        HapticService.medium();
        GlobalToast.show(
          title: 'Botella por agotarse',
          body: '$body',
          kind: GlobalToastKind.warning,
          duration: const Duration(seconds: 6),
        );
        showLocalNotification('Botella por agotarse', '$body');
        RefreshBus.emit(RefreshChannel.bar);
        break;

      case 'warehouse_container_alert':
        if ((num.tryParse('${data['vencidos']}') ?? 0) <= 0) break;
        final body = data['mensaje'] ??
            '${data['pendientes'] ?? 0} envase(s) esperan recepción en almacén.';
        HapticService.medium();
        GlobalToast.show(
          title: 'Envases sin recibir',
          body: '$body',
          kind: GlobalToastKind.warning,
          duration: const Duration(seconds: 6),
        );
        showLocalNotification('Envases sin recibir', '$body');
        break;

      // ─── Catálogo, asistencia, permisos y sesión ────────────────────────
      case 'categories_updated':
        RefreshBus.emit(RefreshChannel.categories);
        break;

      case 'check_attendance':
        final rolesAfectados = (data['roles'] is List ? data['roles'] as List : const [])
            .map((r) => '$r'.toLowerCase())
            .toList();
        if (rolesAfectados.isNotEmpty && !rolesAfectados.contains(role)) break;
        _checkAttendanceToday(data['message']?.toString(), user.id);
        break;

      case 'permissions-updated':
        if (data['roleId'] == null) {
          GlobalToast.show(
            title: 'Permisos actualizados',
            body: 'Se aplicarán a tus próximas acciones',
            kind: GlobalToastKind.info,
            duration: const Duration(seconds: 4),
          );
        }
        _ref.read(authProvider.notifier).refreshUser();
        break;

      case 'role-deleted':
        _ref.read(authProvider.notifier).refreshUser().then((ok) {
          if (!ok) _ref.read(authProvider.notifier).logout();
        });
        break;

      case 'force_logout':
        final reason = data['message']?.toString() ?? 'Tu cuenta fue eliminada.';
        HapticService.heavy();
        GlobalToast.show(
          title: 'Sesión cerrada',
          body: reason,
          kind: GlobalToastKind.error,
          duration: const Duration(seconds: 5),
        );
        showLocalNotification('Sesión cerrada', reason);
        _ref.read(authProvider.notifier).logout();
        break;

      // ─── Gratificaciones (solo administración) ──────────────────────────
      case 'new_gratificacion_request':
        HapticService.medium();
        GlobalToast.show(
          title: 'Nueva solicitud de gratificación',
          body:
              '${data['empleado'] ?? data['nick'] ?? 'Empleado'} solicitó una gratificación de ${_money(data['monto'])}',
          kind: GlobalToastKind.info,
          duration: const Duration(seconds: 5),
        );
        showLocalNotification(
            'Nueva solicitud de gratificación',
            '${data['empleado'] ?? data['nick'] ?? 'Empleado'} solicitó una gratificación de ${_money(data['monto'])}');
        RefreshBus.emit(RefreshChannel.gratificaciones);
        break;

      case 'gratificacion_processed':
        final aprobada =
            data['accion'] == 'approve' || (num.tryParse('${data['estado']}') ?? 0) == 1;
        final body =
            '${data['nick'] ?? data['empleado'] ?? 'Empleado'} - ${_money(data['monto'])}';
        HapticService.trigger(aprobada ? 'light' : 'medium');
        GlobalToast.show(
          title: aprobada ? 'Gratificación aprobada' : 'Gratificación rechazada',
          body: body,
          kind: aprobada ? GlobalToastKind.success : GlobalToastKind.error,
          duration: const Duration(seconds: 5),
        );
        showLocalNotification(
            aprobada ? 'Gratificación aprobada' : 'Gratificación rechazada', body);
        RefreshBus.emit(RefreshChannel.gratificaciones);
        break;

      case 'security_alert':
        final critico = ['high', 'critical']
            .contains('${data['severity'] ?? ''}'.toLowerCase());
        final body = data['message']?.toString() ??
            'Revisa la actividad reciente en el dashboard.';
        HapticService.trigger(critico ? 'heavy' : 'medium');
        GlobalToast.show(
          title: 'Alerta de seguridad',
          body: body,
          kind: critico ? GlobalToastKind.error : GlobalToastKind.warning,
          duration: const Duration(seconds: 7),
        );
        showLocalNotification('Alerta de seguridad', body);
        break;

      // ─── Dirigidos: perfil, código de asistencia ────────────────────────
      case 'profile_updated':
        final target = data['userId'] ?? data['id'];
        if (target != null && target.toString() == user.id) {
          _ref.read(authProvider.notifier).refreshUser();
          RefreshBus.emit(RefreshChannel.profile);
        }
        break;

      case 'code_changed':
        RefreshBus.emit(RefreshChannel.attendanceCode);
        break;

      case 'attendance_registered':
        RefreshBus.emit(RefreshChannel.attendanceCode);
        break;

      default:
        // Eventos atendidos por otros dueños (staff_call, assistance_request)
        // o fuera del catálogo: no hay nada que hacer.
        break;
    }
  }

  /// Cron de las 21:00: si el personal afectado no registró asistencia hoy se
  /// le pide re-ingresar (igual que el dashboard y la app Expo).
  Future<void> _checkAttendanceToday(String? message, String userId) async {
    try {
      final api = _ref.read(apiClientProvider);
      final res = await api.dio.get('/attendance/hoy');
      final body = res.data;
      final rows = body is Map && body['data'] is List ? body['data'] as List : const [];
      final registrada =
          rows.any((f) => f is Map && '${f['id_usuario']}' == userId);
      if (registrada) return;

      final text = message ??
          'No registraste tu asistencia hoy. Ingresa nuevamente para registrarla.';
      HapticService.medium();
      GlobalToast.show(
        title: 'Asistencia no registrada',
        body: text,
        kind: GlobalToastKind.warning,
        duration: const Duration(seconds: 6),
      );
      showLocalNotification('Asistencia no registrada', text);
      await _ref.read(authProvider.notifier).logout();
    } catch (_) {
      // Sin red no se castiga: el próximo evento vuelve a chequear.
    }
  }

  static String _money(dynamic v) {
    final n = num.tryParse('${v ?? 0}') ?? 0;
    final text = n.toStringAsFixed(0);
    final separated =
        text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return '\$$separated';
  }
}

/// Único dispatcher de la app: se watchea una sola vez desde `MyApp`.
final sseDispatcherProvider = Provider<SseDispatcher>((ref) {
  final dispatcher = SseDispatcher(ref);

  final sseAsync = ref.watch(sseEventStreamProvider);
  sseAsync.whenData(dispatcher.handle);

  return dispatcher;
});
