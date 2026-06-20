import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/haptic_service.dart';
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
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    
    Future.microtask(() {
      ref.read(garzonDashboardProvider.notifier).fetchDashboardData();
    });
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

                    
                    _buildPayoutCard(isDark, dashboardState.payoutTotal),
                    const SizedBox(height: 20),

                    
                    Text(
                      'Calendario Operativo',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCalendarCard(isDark, dashboardState.eventDays),
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

  Widget _buildPayoutCard(bool isDark, double payoutTotal) {
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Liquidación',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(bool isDark, Set<int> eventDays) {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    
    final firstDayOfMonth = DateTime(year, month, 1);
    final totalDays = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; 

    final monthName = DateFormat('MMMM yyyy', 'es_CL').format(now);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthName.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['LU', 'MA', 'MI', 'JU', 'VI', 'SÁ', 'DO'].map((day) {
              return SizedBox(
                width: 32,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 35, 
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - (startWeekday - 1) + 1;
              final isValidDay = dayNumber > 0 && dayNumber <= totalDays;

              if (!isValidDay) {
                return const SizedBox(width: 32, height: 32);
              }

              final isToday = dayNumber == now.day;
              final hasEvent = eventDays.contains(dayNumber);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = DateTime(year, month, dayNumber);
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : (_selectedDate.day == dayNumber
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.15)
                            : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isToday || _selectedDate.day == dayNumber
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday
                              ? Colors.white
                              : (_selectedDate.day == dayNumber
                                  ? Theme.of(context).colorScheme.primary
                                  : (isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary)),
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.white
                                  : AppTheme.secondaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
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
