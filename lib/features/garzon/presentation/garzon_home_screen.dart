import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/report_service.dart';
import '../../../core/theme.dart';
import '../../../core/haptic_service.dart';
import '../../../core/refresh_bus.dart';
import '../../../core/widgets/liquidation_export.dart';
import '../../../core/widgets/operations_calendar.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/premium_header.dart';
import '../../auth/data/auth_notifier.dart';
import '../data/dashboard_notifier.dart';

class GarzonHomeScreen extends ConsumerStatefulWidget {
  const GarzonHomeScreen({super.key});

  @override
  ConsumerState<GarzonHomeScreen> createState() => _GarzonHomeScreenState();
}

class _GarzonHomeScreenState extends ConsumerState<GarzonHomeScreen> {
  /// Días (clave `yyyy-MM-dd`) marcados en el calendario operativo.
  final Set<String> _selectedDates = {};
  StreamSubscription<RefreshChannel>? _refreshSub;

  @override
  void initState() {
    super.initState();
    
    Future.microtask(() {
      ref.read(garzonDashboardProvider.notifier).fetchDashboardData();
    });
    _refreshSub = RefreshBus.stream.listen((channel) {
      if (channel == RefreshChannel.dashboard ||
          channel == RefreshChannel.requests) {
        ref.read(garzonDashboardProvider.notifier).fetchDashboardData();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(garzonDashboardProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double weeklyGoal = 300000;
    final double progressPercent = dashboardState.totalEarnings > 0
        ? (dashboardState.totalEarnings / weeklyGoal) * 100
        : 0;

    if (dashboardState.isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: SkeletonStatCard(),
          ),
        ),
      );
    }

    final userDisplayName = user?.nombre ?? 'Garzón';
    final events = dashboardState.events
        .map(LiquidationEvent.fromJson)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(title: userDisplayName),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(garzonDashboardProvider.notifier)
                    .fetchDashboardData(isManual: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    Text(
                      'Métricas del Período',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatsCard(
                      isDark,
                      dashboardState.totalEarnings,
                      dashboardState.salesWithTips,
                      progressPercent,
                    ),
                    const SizedBox(height: 16),

                    
                    _buildPayoutCard(
                      isDark,
                      dashboardState.payoutTotal,
                      events,
                      liquidationUserLabel(
                        user?.nombre ?? '',
                        nick: user?.nick ?? '',
                      ),
                    ),
                    const SizedBox(height: 20),

                    
                    Text(
                      'Calendario Operativo',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OperationsCalendar(
                      events: events,
                      selectedDates: _selectedDates,
                      onDateToggle: (dateKey) {
                        HapticService.light();
                        setState(() {
                          if (!_selectedDates.remove(dateKey)) {
                            _selectedDates.add(dateKey);
                          }
                        });
                      },
                    ),
                    if (_selectedDates.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectedDaysBar(
                        count: _selectedDates.length,
                        onDetails: () => showSelectedEventsSheet(
                          context,
                          events: events,
                          selectedDates: _selectedDates,
                          userRole: user?.role,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            title: 'PEDIDOS',
                            subtitle: 'Comandas de Mesa',
                            icon: Icons.restaurant_menu_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            onTap: () {
                              HapticService.light();
                              context.push('/garzon/productos');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionCard(
                            title: 'SERVICIOS',
                            subtitle: 'Registro de Atención',
                            icon: Icons.room_service_rounded,
                            color: AppTheme.secondaryColor,
                            onTap: () {
                              HapticService.light();
                              context.push('/garzon/servicios');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Enlace a Eventos Financieros (paridad con el tab
                    // «Propinas» de Expo, que ES esta pantalla).
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            title: 'FINANCIERO',
                            subtitle: 'Eventos y propinas',
                            icon: Icons.payments_rounded,
                            color: AppTheme.successColor,
                            onTap: () {
                              HapticService.light();
                              context.push('/garzon/financieros');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          // Ruta existente sin enlaces (auditoría de paridad):
                          // /garzon/analytics era huérfana.
                          child: _buildActionCard(
                            title: 'ANALÍTICAS',
                            subtitle: 'Métricas y ventas',
                            icon: Icons.insights_rounded,
                            color: AppTheme.secondaryColor,
                            onTap: () {
                              HapticService.light();
                              context.push('/garzon/analytics');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    bool isDark,
    double totalEarnings,
    int salesWithTips,
    double progressPercent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Propinas',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(totalEarnings),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Comandas con Propina',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$salesWithTips ventas',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 100,
            color: isDark
                ? AppTheme.darkBorderColor
                : AppTheme.lightBorderColor,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: progressPercent / 100,
                      strokeWidth: 8,
                      backgroundColor: isDark
                          ? AppTheme.darkBorderColor
                          : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${progressPercent.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'de meta',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Meta: \$300.000',
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
        ],
      ),
    );
  }

  Widget _buildPayoutCard(
    bool isDark,
    double payoutTotal,
    List<LiquidationEvent> events,
    String userLabel,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acumulado para Retiro',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatCurrency(payoutTotal),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // El chip decorativo «Liquidación» pasó a ser el export real de
              // la liquidación (paridad con el botón «Reportes» de
              // PremiumLiquidationCard en Expo).
              LiquidationExportButton(
                dense: true,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                events: events,
                userLabel: userLabel,
                totalAmount: payoutTotal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
