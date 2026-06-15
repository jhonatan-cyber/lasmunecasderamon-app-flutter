import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/api_client.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/currency_text.dart';
import '../../auth/data/auth_notifier.dart';
import '../../auth/presentation/widgets/registro_asistencia_modal.dart';

class GarzonHomeScreen extends ConsumerStatefulWidget {
  const GarzonHomeScreen({super.key});

  @override
  ConsumerState<GarzonHomeScreen> createState() => _GarzonHomeScreenState();
}

class _GarzonHomeScreenState extends ConsumerState<GarzonHomeScreen> {
  DateTime _selectedDate = DateTime.now();
  Set<int> _eventDays = {};
  bool _loadingStats = true;
  bool _refreshing = false;
  String _error = '';

  // Real data from API
  double _totalEarnings = 0;
  int _salesWithTips = 0;
  double _payoutTotal = 0;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData({bool isManual = false}) async {
    if (!isManual && !mounted) return;
    setState(() {
      _loadingStats = !isManual;
      _error = '';
    });

    try {
      final client = ref.read(apiClientProvider);
      final responses = await Future.wait<Response<dynamic>?>([
        client.dio.get('/events/user').then<Response<dynamic>?>((r) => r).catchError((_) => null),
        client.dio.get('/events/stats').then<Response<dynamic>?>((r) => r).catchError((_) => null),
        client.dio.get('/users/me/stats').then<Response<dynamic>?>((r) => r).catchError((_) => null),
      ]);

      // Parse events
      final eventsRes = responses[0];
      List<Map<String, dynamic>> events = [];
      if (eventsRes != null && eventsRes.data != null) {
        final rawEvents = eventsRes.data['success'] == true ? eventsRes.data['data'] : (eventsRes.data is List ? eventsRes.data : null);
        if (rawEvents is List) {
          events = rawEvents.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      // Parse stats
      final statsRes = responses[1];
      double totalEarnings = 0;
      int salesWithTips = 0;
      if (statsRes != null && statsRes.data != null) {
        final statsData = statsRes.data['success'] == true ? statsRes.data['data'] : statsRes.data;
        if (statsData is Map) {
          totalEarnings = double.tryParse(statsData['totalEarnings']?.toString() ?? '0') ?? 0.0;
          salesWithTips = int.tryParse(statsData['svcCount']?.toString() ?? '0') ?? 0;
        }
      }

      // Parse payout total
      final meStatsRes = responses[2];
      double payoutTotal = 0;
      if (meStatsRes != null && meStatsRes.data != null) {
        final data = meStatsRes.data['success'] == true ? meStatsRes.data['data'] : meStatsRes.data;
        if (data is Map && data['stats'] is Map) {
          payoutTotal = double.tryParse(data['stats']['montoAnticipoMaximo']?.toString() ?? '0') ?? 0.0;
        }
      }

      // Build event days for calendar visual
      final Set<int> eventDays = {};
      for (var e in events) {
        final dateStr = e['date']?.toString();
        if (dateStr != null) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null) {
            final now = DateTime.now();
            if (parsed.year == now.year && parsed.month == now.month) {
              eventDays.add(parsed.day);
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _totalEarnings = totalEarnings;
        _salesWithTips = salesWithTips;
        _payoutTotal = payoutTotal;
        _eventDays = eventDays;
        _loadingStats = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar datos del dashboard';
        _loadingStats = false;
        _refreshing = false;
      });
    }
    // Read unused fields to silence warnings
    debugPrint('Home state: ${_events.length} events, error: $_error, refreshing: $_refreshing');
  }
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double weeklyGoal = 300000;
    final double progressPercent = _totalEarnings > 0 ? (_totalEarnings / weeklyGoal) * 100 : 0;

    if (_loadingStats) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  user?.nombre.isNotEmpty == true ? user!.nombre[0].toUpperCase() : 'G',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hola, ${user?.nombre ?? 'Garzón'}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Garzón • En Turno', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: SkeletonStatCard(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        elevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => context.push('/garzon/perfil'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: user?.foto.isNotEmpty == true
                    ? NetworkImage(
                        user!.foto.startsWith('http')
                            ? user.foto
                            : '${ApiClient.baseUrl}/img/users/${user.foto}',
                      )
                    : null,
                child: user?.foto.isNotEmpty == true
                    ? null
                    : Text(
                        user?.nombre.isNotEmpty == true ? user!.nombre[0].toUpperCase() : 'G',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hola, ${user?.nombre ?? 'Garzón'}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Garzón • En Turno',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryColor),
            onPressed: () {
              RegistroAsistenciaModal.show(context, () {
                // Asistencia registrada
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _refreshing = true);
          await _fetchDashboardData(isManual: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Section
              Text(
                'Métricas del Período',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                isDark,
                _totalEarnings,
                _salesWithTips,
                progressPercent,
              ),
              const SizedBox(height: 16),

              // Payout Card
              _buildPayoutCard(isDark, _payoutTotal),
              const SizedBox(height: 20),

              // Calendar Section
              Text(
                'Calendario Operativo',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCalendarCard(isDark),
              const SizedBox(height: 24),

              // Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'PEDIDOS',
                      subtitle: 'Comandas de Mesa',
                      icon: Icons.restaurant_menu_rounded,
                      color: AppTheme.primaryColor,
                      onTap: () => context.push('/garzon/productos'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      title: 'SERVICIOS',
                      subtitle: 'Registro de Atención',
                      icon: Icons.room_service_rounded,
                      color: AppTheme.secondaryColor,
                      onTap: () => context.push('/garzon/servicios'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isDark, double totalEarnings, int salesWithTips, double progressPercent) {
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
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(totalEarnings),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Comandas con Propina',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
            color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
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
                      backgroundColor: isDark ? AppTheme.darkBorderColor : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
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

  Widget _buildCalendarCard(bool isDark) {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Simple Monthly Calendar Calculation
    final firstDayOfMonth = DateTime(year, month, 1);
    final totalDays = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Lunes, 7 = Domingo

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
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 12),
          // Weekdays row
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
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 35, // 5 rows x 7 days
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
              final hasEvent = _eventDays.contains(dayNumber);

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
                        ? AppTheme.primaryColor
                        : (_selectedDate.day == dayNumber
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
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
                                  ? AppTheme.primaryColor
                                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isToday ? Colors.white : AppTheme.secondaryColor,
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
          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
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
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
