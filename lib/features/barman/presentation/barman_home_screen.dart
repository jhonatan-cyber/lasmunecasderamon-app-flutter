import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/hooks/refresh_provider.dart';
import '../../../core/refresh_bus.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/currency_text.dart';
import '../../auth/data/auth_notifier.dart';

/// Home del rol Barman, espejo de `HomeScreen role="barman"` de la app Expo:
/// tarjeta de ganancias, métricas de la semana/servicios, contador de envases
/// del control bar→almacén y el grid de acciones (Bar, Ventas, Servicios).
class BarmanHomeScreen extends ConsumerStatefulWidget {
  const BarmanHomeScreen({super.key});

  @override
  ConsumerState<BarmanHomeScreen> createState() => _BarmanHomeScreenState();
}

class _BarmanHomeScreenState extends ConsumerState<BarmanHomeScreen> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _containers;
  StreamSubscription<RefreshChannel>? _refreshSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
    _refreshSub = RefreshBus.stream.listen((channel) {
      if (channel == RefreshChannel.dashboard || channel == RefreshChannel.bar) {
        _fetchData();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('barman_home').notifier);
    notifier.startRefresh(isManual: isManual);

    try {
      final client = ref.read(apiClientProvider);

      // Mismo contracto que useDashboardData.ts de Expo (results[0..4]):
      // eventos propios, sesión, estado y stats del usuario; el rol barman
      // añade stock resumido del bar, transferencias y contador de envases.
      final results = await Future.wait([
        client.dio.get('/events/user').catchError((e) => _emptyResponse()),
        client.dio.get('/auth/me').catchError((e) => _emptyResponse()),
        client.dio.get('/users/status').catchError((e) => _emptyResponse()),
        client.dio.get('/users/me/stats').catchError((e) => _emptyResponse()),
        client.dio.get('/events/stats').catchError((e) => _emptyResponse()),
        client.dio.get('/bar/containers/summary').catchError((e) => _emptyResponse()),
      ]);

      final meStats = _dataOf(results[3].data);
      final containers = _dataOf(results[5].data);

      if (!mounted) return;
      setState(() {
        _stats = meStats ?? {};
        _containers = containers;
      });
      notifier.endRefresh();
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: 'Error al cargar datos del panel');
    }
  }

  static Response<dynamic> _emptyResponse() =>
      Response(requestOptions: RequestOptions(), data: {'success': false});

  static Map<String, dynamic>? _dataOf(dynamic body) {
    if (body is Map && body['success'] == true && body['data'] is Map) {
      return (body['data'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  void _showLogoutConfirmation(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        title: Text('Cerrar sesión',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro que deseas salir del sistema?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : Colors.black87)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: Text('Cerrar Sesión',
                style: GoogleFonts.inter(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final refresh = ref.watch(refreshProvider('barman_home'));
    final accent = Theme.of(context).colorScheme.primary;

    final fullName = user?.nombre ?? 'Barman';
    final nick = (user?.nick.isNotEmpty == true)
        ? user!.nick
        : (user?.nombre.toLowerCase().replaceAll(' ', '') ?? 'barman');

    final double totalEarnings =
        double.tryParse('${_stats['totalEarnings'] ?? 0}') ?? 0;
    final int svcCount = int.tryParse('${_stats['svcCount'] ?? 0}') ?? 0;

    final int pendientes =
        int.tryParse('${_containers?['pendientes'] ?? 0}') ?? 0;
    final int vencidos = int.tryParse('${_containers?['vencidos'] ?? 0}') ?? 0;
    final int umbralHoras =
        int.tryParse('${_containers?['umbral_horas'] ?? 2}') ?? 2;
    final Color envasesColor = vencidos > 0
        ? const Color(0xFFEF4444)
        : pendientes > 0
            ? const Color(0xFFF59E0B)
            : accent;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: RefreshIndicator(
        onRefresh: () => _fetchData(isManual: true),
        color: accent,
        child: refresh.isLoading
            ? Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accent)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent,
                            const Color(0xFF881337),
                            const Color(0xFF1A0B10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _headerButton(
                                    icon: Icons.settings_outlined,
                                    onPressed: () => context.push('/barman/perfil'),
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 12),
                                  _headerButton(
                                    icon: isDark
                                        ? Icons.wb_sunny_rounded
                                        : Icons.nightlight_round_outlined,
                                    onPressed: () {
                                      ref.read(themeModeProvider.notifier).state =
                                          isDark ? ThemeMode.light : ThemeMode.dark;
                                    },
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 12),
                                  _headerButton(
                                    icon: Icons.logout_rounded,
                                    onPressed: () =>
                                        _showLogoutConfirmation(context, isDark),
                                    isDark: isDark,
                                    color: Colors.redAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                              Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.12),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        fullName.isNotEmpty
                                            ? fullName[0].toUpperCase()
                                            : 'B',
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('@$nick',
                                            style: GoogleFonts.inter(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text(fullName,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text('Barman',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                )),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (refresh.error.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(refresh.error,
                                        style: GoogleFonts.inter(
                                            color: Colors.redAccent,
                                            fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _statCard(
                            isDark: isDark,
                            label: 'GANANCIAS',
                            value: formatCurrency(totalEarnings),
                            subLabel: '$svcCount movimientos',
                            icon: Icons.wallet_rounded,
                            color: const Color(0xFF10B981),
                            fullWidth: true,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  isDark: isDark,
                                  label: 'ESTA SEMANA',
                                  value: formatCurrency(0),
                                  icon: Icons.trending_up_rounded,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  isDark: isDark,
                                  label: 'SERVICIOS',
                                  value: '$svcCount',
                                  icon: Icons.work_outline_rounded,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_containers != null)
                            _statCard(
                              isDark: isDark,
                              label: 'ENVASES',
                              value: '$pendientes',
                              subLabel: vencidos > 0
                                  ? '$vencidos con más de $umbralHoras h'
                                  : pendientes > 0
                                      ? 'Pendientes de recepción'
                                      : 'Sin pendientes',
                              icon: Icons.inventory_2_outlined,
                              color: envasesColor,
                              fullWidth: true,
                            ),
                          const SizedBox(height: 24),
                          Text('Operaciones del Bar',
                              style: GoogleFonts.inter(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildActionGrid(accent, isDark),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _statCard({
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subLabel,
    bool fullWidth = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(fullWidth ? 20 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(fullWidth ? 24 : 18),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.25)
              : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            fullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: fullWidth ? 32 : 18,
                  fontWeight: FontWeight.w900)),
          if (subLabel != null) ...[
            const SizedBox(height: 4),
            Text(subLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildActionGrid(Color accent, bool isDark) {
    final actions = [
      (
        title: 'BAR',
        desc: 'Stock y transferencias',
        icon: Icons.sports_bar_rounded,
        route: '/barman/bar',
      ),
      (
        title: 'VENTAS',
        desc: 'Ventas del día',
        icon: Icons.shopping_cart_rounded,
        route: '/barman/ventas',
      ),
      (
        title: 'SERVICIOS',
        desc: 'Gestión de privados',
        icon: Icons.hotel_rounded,
        route: '/barman/servicios',
      ),
      (
        title: 'FINANCIERO',
        desc: 'Eventos y propinas',
        icon: Icons.payments_rounded,
        route: '/barman/financieros',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: () => context.push(action.route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: accent, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.title,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(action.desc,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
