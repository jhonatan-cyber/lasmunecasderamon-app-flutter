import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/api_client.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/widgets/currency_text.dart';
import '../../auth/data/auth_notifier.dart';

class CajeroHomeScreen extends ConsumerStatefulWidget {
  const CajeroHomeScreen({super.key});

  @override
  ConsumerState<CajeroHomeScreen> createState() => _CajeroHomeScreenState();
}

class _CajeroHomeScreenState extends ConsumerState<CajeroHomeScreen> {
  Map<String, dynamic> _stats = {};
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
  }

  Future<void> _fetchData({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('cajero_home').notifier);
    notifier.startRefresh(isManual: isManual);

    try {
      final client = ref.read(apiClientProvider);

      dynamic statsRes;
      try {
        statsRes = await client.dio.get('/caja/stats');
      } catch (_) {}

      dynamic pendingRes;
      try {
        pendingRes = await client.dio.get(
          '/solicitudes-servicios/pending-count',
        );
      } catch (_) {}

      Map<String, dynamic> statsData = {};
      if (statsRes != null &&
          statsRes.data != null &&
          statsRes.data['success'] == true) {
        statsData = statsRes.data['data'] ?? {};
      }

      int pendingVal = 0;
      if (pendingRes != null && pendingRes.data != null) {
        pendingVal = pendingRes.data['count'] ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _stats = statsData;
        _pendingCount = pendingVal;
      });
      notifier.endRefresh();
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: 'Error al cargar datos del panel');
    }
  }

  void _showLogoutConfirmation(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.lightSurfaceColor,
        title: Text(
          'Cerrar sesiÃ³n',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Â¿EstÃ¡s seguro que deseas salir del sistema?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: Text(
              'Cerrar SesiÃ³n',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
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
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final double balanceTotal =
        double.tryParse(_stats['balance_total']?.toString() ?? '0') ?? 0.0;
    final double totalVentas =
        double.tryParse(_stats['total_ventas']?.toString() ?? '0') ?? 0.0;
    final double totalServicios =
        double.tryParse(_stats['total_servicios']?.toString() ?? '0') ?? 0.0;
    final double montoApertura =
        double.tryParse(_stats['monto_apertura']?.toString() ?? '0') ?? 0.0;
    final int cantidadVentas =
        int.tryParse(_stats['cantidad_ventas']?.toString() ?? '0') ?? 0;
    final int cantidadServicios =
        int.tryParse(_stats['cantidad_servicios']?.toString() ?? '0') ?? 0;

    final fullName = user?.nombre ?? "Cajero";
    final nick = (user?.nick.isNotEmpty == true)
        ? user!.nick
        : (user?.nombre.toLowerCase().replaceAll(' ', '') ?? "cajero");

    final refresh = ref.watch(refreshProvider('cajero_home'));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: RefreshIndicator(
        onRefresh: () => _fetchData(isManual: true),
        color: Theme.of(context).colorScheme.primary,
        child: refresh.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets
                    .zero, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
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
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 20.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildHeaderButton(
                                    icon: Icons.people_outline_rounded,
                                    onPressed: () =>
                                        context.push('/cajero/personal'),
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 12),
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      _buildHeaderButton(
                                        icon: Icons.notifications_none_rounded,
                                        onPressed: () =>
                                            context.push('/cajero/solicitudes'),
                                        isDark: isDark,
                                      ),
                                      if (_pendingCount > 0)
                                        Positioned(
                                          right: 2,
                                          top: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 16,
                                              minHeight: 16,
                                            ),
                                            child: Text(
                                              '$_pendingCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  _buildHeaderButton(
                                    icon: Icons.settings_outlined,
                                    onPressed: () =>
                                        context.push('/cajero/perfil'),
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildHeaderButton(
                                    icon: isDark
                                        ? Icons.wb_sunny_rounded
                                        : Icons.nightlight_round_outlined,
                                    onPressed: () {
                                      ref
                                          .read(themeModeProvider.notifier)
                                          .state = isDark
                                          ? ThemeMode.light
                                          : ThemeMode.dark;
                                    },
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildHeaderButton(
                                    icon: Icons.logout_rounded,
                                    onPressed: () => _showLogoutConfirmation(
                                      context,
                                      isDark,
                                    ),
                                    isDark: isDark,
                                    color: Colors.redAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => context.push('/cajero/perfil'),
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                        image: user?.foto.isNotEmpty == true
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  user!.foto.startsWith('http')
                                                      ? user.foto
                                                      : '${ApiClient.baseDomain}/img/users/${user.foto}',
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: user?.foto.isNotEmpty == true
                                          ? null
                                          : Center(
                                              child: Text(
                                                user?.nombre.isNotEmpty == true
                                                    ? user!.nombre[0]
                                                          .toUpperCase()
                                                    : 'C',
                                                style: GoogleFonts.inter(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
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
                                        Text(
                                          '@$nick',
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          fullName,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(
                                                  0xFF10B981,
                                                ), 
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Cajero',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
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
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (refresh.error.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      refresh.error,
                                      style: GoogleFonts.inter(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Text(
                            'Resumen de Caja',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildBalanceCard(
                            isDark,
                            balanceTotal,
                            montoApertura,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  isDark: isDark,
                                  label: 'VENTAS',
                                  value: formatCurrency(totalVentas),
                                  subtitle: '$cantidadVentas ventas',
                                  icon: Icons.shopping_cart_rounded,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  isDark: isDark,
                                  label: 'SERVICIOS',
                                  value: formatCurrency(totalServicios),
                                  subtitle: '$cantidadServicios servicios',
                                  icon: Icons.hotel_rounded,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Operaciones de Caja',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildActionGrid(),
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

  Widget _buildBalanceCard(bool isDark, double total, double apertura) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BALANCE TOTAL EN CAJA',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Activo',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(total),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ ${formatCurrency(apertura)} de Apertura Base',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      _ActionData(
        title: 'VENTAS',
        desc: 'Nueva venta',
        icon: Icons.shopping_cart_rounded,
        route: '/cajero/ventas',
        color: Theme.of(context).colorScheme.primary,
      ),
      _ActionData(
        title: 'CUENTAS',
        desc: 'Cuentas activas',
        icon: Icons.receipt_long_rounded,
        route: '/cajero/cuentas',
        color: Theme.of(context).colorScheme.primary,
      ),
      _ActionData(
        title: 'SERVICIOS',
        desc: 'GestiÃ³n privados',
        icon: Icons.hotel_rounded,
        route: '/cajero/servicios',
        color: Theme.of(context).colorScheme.primary,
      ),
      _ActionData(
        title: 'CAJA',
        desc: 'Apertura y cierres',
        icon: Icons.point_of_sale_rounded,
        route: '/cajero/caja',
        color: Theme.of(context).colorScheme.primary,
      ),
      _ActionData(
        title: 'SOLICITUDES',
        desc: 'Mozos y anticipos',
        icon: Icons.notifications_active_rounded,
        route: '/cajero/solicitudes',
        color: Theme.of(context).colorScheme.primary,
      ),
      _ActionData(
        title: 'CLIENTES',
        desc: 'Saldos prepago',
        icon: Icons.person_search_rounded,
        route: '/cajero/clientes',
        color: Theme.of(context).colorScheme.primary,
      ),
      _ActionData(
        title: 'PERSONAL',
        desc: 'LiquidaciÃ³n',
        icon: Icons.groups_rounded,
        route: '/cajero/administrativo',
        color: Theme.of(context).colorScheme.primary,
      ),
      _ActionData(
        title: 'GRATIFICACIONES',
        desc: 'Bonos admin',
        icon: Icons.card_giftcard_rounded,
        route: '/cajero/gratificaciones',
        color: Theme.of(context).colorScheme.primary,
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return InkWell(
          onTap: () => context.push(action.route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceColor
                  : AppTheme.lightSurfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppTheme.darkBorderColor
                    : AppTheme.lightBorderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: action.color, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.desc,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _ActionData {
  final String title;
  final String desc;
  final IconData icon;
  final String route;
  final Color color;

  _ActionData({
    required this.title,
    required this.desc,
    required this.icon,
    required this.route,
    required this.color,
  });
}
