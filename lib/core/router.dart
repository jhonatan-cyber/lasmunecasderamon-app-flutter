import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_notifier.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/reset_password_confirm_screen.dart';
import '../features/auth/presentation/verify_code_screen.dart';
import 'widgets/offline_banner.dart';
import '../features/garzon/presentation/productos_screen.dart';
import '../features/garzon/presentation/garzon_tabs_layout.dart';
import '../features/garzon/presentation/garzon_home_screen.dart';
import '../features/garzon/presentation/servicios_screen.dart';
import '../features/garzon/presentation/asistencia_screen.dart';
import '../features/garzon/presentation/anticipos_screen.dart';
import '../features/garzon/presentation/propinas_screen.dart';
import '../features/garzon/presentation/horas_extras_screen.dart';
import '../features/cajero/presentation/cajero_home_screen.dart';
import '../features/cajero/presentation/caja_screen.dart';
import '../features/cajero/presentation/ventas_screen.dart';
import '../features/cajero/presentation/nueva_venta_screen.dart';
import '../features/cajero/presentation/cuentas_screen.dart';
import '../features/cajero/presentation/nueva_cuenta_screen.dart';
import '../features/cajero/presentation/agregar_cuenta_screen.dart';
import '../features/cajero/presentation/servicios_screen.dart' as cajero_srv;
import '../features/cajero/presentation/nuevo_servicio_screen.dart';
import '../features/cajero/presentation/cajero_tabs_layout.dart';
import '../features/auth/presentation/perfil_screen.dart';
import '../features/cajero/presentation/personal_screen.dart';
import '../features/cajero/presentation/clientes_screen.dart';
import '../features/cajero/presentation/solicitudes_screen.dart';
import '../features/cajero/presentation/administrativo_screen.dart';
import '../features/cajero/presentation/horas_extras_admin_screen.dart';
import '../features/cajero/presentation/gratificaciones_screen.dart';
import '../features/anfitriona/presentation/anfitriona_home_screen.dart';
import '../features/anfitriona/presentation/anfitriona_servicios_screen.dart';
import '../features/anfitriona/presentation/anfitriona_comisiones_screen.dart';
import '../features/anfitriona/presentation/anfitriona_tabs_layout.dart';
import '../features/financial/presentation/financial_events_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = authState.user;
      final loggedIn = user != null;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/verify-code';

      if (!loggedIn) {
        return isLoggingIn ? null : '/login';
      }
      if (isLoggingIn || state.matchedLocation == '/') {
        if (user.isGarzon) {
          return '/garzon';
        } else if (user.isHostess) {
          return '/anfitriona';
        } else if (user.isCajeroOrAdmin) {
          return '/cajero';
        }
        return '/garzon';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/verify-code',
        builder: (context, state) => const VerifyCodeScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password/confirm',
        builder: (context, state) => const ResetPasswordConfirmScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) =>
            _OfflineShell(child: GarzonTabsLayout(child: child)),
        routes: [
          GoRoute(
            path: '/garzon',
            builder: (context, state) => const GarzonHomeScreen(),
          ),
          GoRoute(
            path: '/garzon/asistencia',
            builder: (context, state) => const AsistenciaScreen(),
          ),
          GoRoute(
            path: '/garzon/anticipos',
            builder: (context, state) => const AnticiposScreen(),
          ),
          GoRoute(
            path: '/garzon/propinas',
            builder: (context, state) => const PropinasScreen(),
          ),
          GoRoute(
            path: '/garzon/horas-extras',
            builder: (context, state) => const HorasExtrasScreen(),
          ),
          GoRoute(
            path: '/garzon/financieros',
            builder: (context, state) => const FinancialEventsScreen(
              title: 'Eventos Financieros',
              subtitle: 'Comisiones y propinas',
              type: 'comisiones',
            ),
          ),
          GoRoute(
            path: '/garzon/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
        ],
      ),

      GoRoute(
        path: '/garzon/productos',
        builder: (context, state) => const ProductosScreen(),
      ),
      GoRoute(
        path: '/garzon/servicios',
        builder: (context, state) => const ServiciosScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) =>
            _OfflineShell(child: AnfitrionaTabsLayout(child: child)),
        routes: [
          GoRoute(
            path: '/anfitriona',
            builder: (context, state) => const AnfitrionaHomeScreen(),
          ),
          GoRoute(
            path: '/anfitriona/servicios',
            builder: (context, state) => const AnfitrionaServiciosScreen(),
          ),
          GoRoute(
            path: '/anfitriona/comisiones',
            builder: (context, state) => const AnfitrionaComisionesScreen(),
          ),
          GoRoute(
            path: '/anfitriona/asistencia',
            builder: (context, state) => const AsistenciaScreen(),
          ),
          GoRoute(
            path: '/anfitriona/anticipos',
            builder: (context, state) => const AnticiposScreen(),
          ),
          GoRoute(
            path: '/anfitriona/financieros',
            builder: (context, state) => const FinancialEventsScreen(
              title: 'Eventos Financieros',
              subtitle: 'Propinas',
              type: 'propinas',
            ),
          ),
          GoRoute(
            path: '/anfitriona/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _OfflineShell(child: CajeroTabsLayout(child: child)),
        routes: [
          GoRoute(
            path: '/cajero',
            builder: (context, state) => const CajeroHomeScreen(),
          ),
          GoRoute(
            path: '/cajero/asistencia',
            builder: (context, state) => const AsistenciaScreen(),
          ),
          GoRoute(
            path: '/cajero/anticipos',
            builder: (context, state) => const AnticiposScreen(),
          ),
          GoRoute(
            path: '/cajero/propinas',
            builder: (context, state) => const PropinasScreen(),
          ),
          GoRoute(
            path: '/cajero/mis-horas-extras',
            builder: (context, state) => const HorasExtrasScreen(),
          ),
          GoRoute(
            path: '/cajero/financieros',
            builder: (context, state) => const FinancialEventsScreen(
              title: 'Eventos Financieros',
              subtitle: 'Comisiones y propinas',
              type: 'comisiones',
            ),
          ),
          GoRoute(
            path: '/cajero/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/cajero/caja',
        builder: (context, state) => const CajaScreen(),
      ),
      GoRoute(
        path: '/cajero/ventas',
        builder: (context, state) => const VentasScreen(),
      ),
      GoRoute(
        path: '/cajero/ventas/nueva',
        builder: (context, state) => const NuevaVentaScreen(),
      ),
      GoRoute(
        path: '/cajero/cuentas',
        builder: (context, state) => const CuentasScreen(),
      ),
      GoRoute(
        path: '/cajero/cuentas/nueva',
        builder: (context, state) => const NuevaCuentaScreen(),
      ),
      GoRoute(
        path: '/cajero/cuentas/agregar/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AgregarCuentaScreen(id: id);
        },
      ),
      GoRoute(
        path: '/cajero/servicios',
        builder: (context, state) => const cajero_srv.ServiciosScreen(),
      ),
      GoRoute(
        path: '/cajero/servicios/nuevo',
        builder: (context, state) => const NuevoServicioScreen(),
      ),
      GoRoute(
        path: '/cajero/solicitudes',
        builder: (context, state) => const CajeroSolicitudesScreen(),
      ),
      GoRoute(
        path: '/cajero/clientes',
        builder: (context, state) => const CajeroClientesScreen(),
      ),
      GoRoute(
        path: '/cajero/administrativo',
        builder: (context, state) => const CajeroAdministrativoScreen(),
      ),
      GoRoute(
        path: '/cajero/personal',
        builder: (context, state) => const CajeroPersonalScreen(),
      ),
      GoRoute(
        path: '/cajero/perfil',
        builder: (context, state) =>
            const PerfilScreen(roleLabel: 'Cajero', avatarEmoji: '💳'),
      ),
      GoRoute(
        path: '/garzon/perfil',
        builder: (context, state) =>
            const PerfilScreen(roleLabel: 'Garzón', avatarEmoji: '🧑'),
      ),
      GoRoute(
        path: '/anfitriona/perfil',
        builder: (context, state) =>
            const PerfilScreen(roleLabel: 'Anfitriona', avatarEmoji: '👸'),
      ),
      GoRoute(
        path: '/cajero/gratificaciones',
        builder: (context, state) => const CajeroGratificacionesScreen(),
      ),
      GoRoute(
        path: '/cajero/horas-extras',
        builder: (context, state) => const CajeroHorasExtrasAdminScreen(),
      ),
    ],
  );
});

class _OfflineShell extends ConsumerWidget {
  const _OfflineShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}
