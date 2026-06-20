import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class AsistenciaScreen extends ConsumerStatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  ConsumerState<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends ConsumerState<AsistenciaScreen> {
  String _activeTab = 'asistencias'; 
  String _filter = 'all'; 
  List<dynamic> _asistencias = [];
  List<dynamic> _gratificaciones = [];
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
  }

  void _navigateMonth(int direction) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + direction, 1);
    });
    _fetchData();
  }

  void _goToCurrentMonth() {
    setState(() {
      _currentDate = DateTime.now();
    });
    _fetchData();
  }

  Future<void> _fetchData({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('asistencia').notifier);
    notifier.startRefresh(isManual: isManual);

    try {
      final client = ref.read(apiClientProvider);

      final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
      final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0);
      final startDateStr = DateFormat('yyyy-MM-dd').format(firstDay);
      final endDateStr = DateFormat('yyyy-MM-dd').format(lastDay);

      final responses = await Future.wait([
        client.dio.get('/attendance/user?tipo=detalle&startDate=$startDateStr&endDate=$endDateStr'),
        client.dio.get('/gratificaciones/me'),
      ]);

      final attendanceRes = responses[0];
      final gratificacionesRes = responses[1];

      List<dynamic> attendanceList = [];
      if (attendanceRes.data != null && attendanceRes.data['success'] == true) {
        attendanceList = attendanceRes.data['data'] ?? [];
      } else if (attendanceRes.data is List) {
        attendanceList = attendanceRes.data;
      }

      List<dynamic> gratList = [];
      if (gratificacionesRes.data != null && gratificacionesRes.data is List) {
        gratList = gratificacionesRes.data;
      } else if (gratificacionesRes.data != null &&
          gratificacionesRes.data['success'] == true) {
        gratList = gratificacionesRes.data['data'] ?? [];
      }

      if (!mounted) return;
      setState(() {
        _asistencias = attendanceList;
        _gratificaciones = gratList;
      });
      notifier.endRefresh();

      if (isManual) notifier.showSuccessSnack(context, 'Datos de asistencia actualizados');
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: 'Error al conectar con el servidor');
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
    try {
      final parsed = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMM yyyy', 'es_CL');
      return formatter.format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _normalizeEstado(dynamic estado) {
    final str = estado.toString().toLowerCase();
    if (str == '1' ||
        str == 'pendiente' ||
        str == 'por_cobrar' ||
        str == 'por cobrar') {
      return 'pendiente';
    }
    if (str == '0' || str == 'pagado' || str == 'cobrado' || str == 'cobrada') {
      return 'pagado';
    }
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentData = _activeTab == 'asistencias'
        ? _asistencias
        : _gratificaciones;

    
    final filteredData = currentData.where((item) {
      if (_activeTab == 'asistencias') {
        final estado = _normalizeEstado(item['estado']);
        if (_filter == 'pendiente') return estado == 'pendiente';
        if (_filter == 'pagado') return estado == 'pagado';
      }
      return true;
    }).toList();

    
    final pendingShifts = _asistencias.where(
      (a) => _normalizeEstado(a['estado']) == 'pendiente',
    );
    final double totalSueldo = pendingShifts.fold(
      0.0,
      (sum, item) =>
          sum + (double.tryParse(item['sueldo']?.toString() ?? '0') ?? 0.0),
    );
    final double totalAporte = pendingShifts.fold(
      0.0,
      (sum, item) =>
          sum + (double.tryParse(item['aporte']?.toString() ?? '0') ?? 0.0),
    );
    final double totalACobrar = totalSueldo - totalAporte;

    final double totalGratificaciones = _gratificaciones.fold(
      0.0,
      (sum, item) =>
          sum + (double.tryParse(item['monto']?.toString() ?? '0') ?? 0.0),
    );

    final accentTheme = ref.watch(accentColorProvider);
    final gradientColors = accentTheme.gradient;
    final refresh = ref.watch(refreshProvider('asistencia'));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Asistencia',
            gradient: gradientColors,
            showRefreshButton: true,
            isRefreshing: refresh.isRefreshing,
            onRefresh: () => _fetchData(isManual: true),
          ),
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: refresh.isLoading,
              skeleton: _buildSkeletonGrid(),
              content: RefreshIndicator(
                onRefresh: () => _fetchData(isManual: true),
                color: Theme.of(context).colorScheme.primary,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  children: [
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildMainTabButton(
                            title: 'Turnos',
                            isActive: _activeTab == 'asistencias',
                            icon: Icons.calendar_month_rounded,
                            onTap: () => setState(() {
                              _activeTab = 'asistencias';
                              _filter = 'all';
                            }),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMainTabButton(
                            title: 'Gratificaciones',
                            isActive: _activeTab == 'gratificaciones',
                            icon: Icons.card_giftcard_rounded,
                            onTap: () => setState(() {
                              _activeTab = 'gratificaciones';
                              _filter = 'all';
                            }),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_activeTab == 'asistencias') ...[
                      _buildMonthNavigation(isDark),
                      const SizedBox(height: 16),
                    ],

                    
                    _buildSummaryCard(
                      isDark: isDark,
                      totalACobrar: totalACobrar,
                      totalSueldo: totalSueldo,
                      totalAporte: totalAporte,
                      totalGratificaciones: totalGratificaciones,
                    ),
                    const SizedBox(height: 16),

                    
                    if (_activeTab == 'asistencias') ...[
                      Row(
                        children: [
                          _buildFilterButton(
                            'all',
                            'Todas (${_asistencias.length})',
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterButton(
                            'pendiente',
                            'Pendientes (${_asistencias.where((a) => _normalizeEstado(a['estado']) == 'pendiente').length})',
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterButton(
                            'pagado',
                            'Pagadas (${_asistencias.where((a) => _normalizeEstado(a['estado']) == 'pagado').length})',
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (refresh.error.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            refresh.error,
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else if (filteredData.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _activeTab == 'asistencias'
                                  ? Icons.calendar_today_rounded
                                  : Icons.card_giftcard_rounded,
                              size: 48,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron registros',
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          final item = filteredData[index];
                          if (_activeTab == 'asistencias') {
                            return _buildAsistenciaCard(item, index, isDark);
                          } else {
                            return _buildGratificacionCard(item, index, isDark);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: const [
                Expanded(child: SkeletonCard(lines: 1)),
                SizedBox(width: 12),
                Expanded(child: SkeletonCard(lines: 1)),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonCard(lines: 3),
            const SizedBox(height: 16),
            ...List.generate(4, (i) => const SkeletonCard(lines: 3)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTabButton({
    required String title,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppTheme.darkSurfaceColor
                      : AppTheme.lightSurfaceColor),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? Colors.white
                    : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required bool isDark,
    required double totalACobrar,
    required double totalSueldo,
    required double totalAporte,
    required double totalGratificaciones,
  }) {
    final color = _activeTab == 'asistencias'
        ? AppTheme.warningColor
        : Theme.of(context).colorScheme.primary;
    final totalAmount = _activeTab == 'asistencias'
        ? totalACobrar
        : totalGratificaciones;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        children: [
          Text(
            _activeTab == 'asistencias'
                ? 'SITUACIÓN DE ASISTENCIAS'
                : 'GRATIFICACIONES ENTREGADAS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(totalAmount),
            style: GoogleFonts.inter(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          if (_activeTab == 'asistencias')
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sueldo: ${_formatCurrency(totalSueldo)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : AppTheme.lightBorderColor,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Text(
                  'Aporte: -${_formatCurrency(totalAporte)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            )
          else
            Text(
              'Total histórico: ${_formatCurrency(totalGratificaciones)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filterVal, String label, bool isDark) {
    final isActive = _filter == filterVal;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _filter = filterVal),
          borderRadius: BorderRadius.circular(9999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                        ? AppTheme.darkSurfaceColor
                        : AppTheme.lightSurfaceColor),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : (isDark
                          ? AppTheme.darkBorderColor
                          : AppTheme.lightBorderColor),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAsistenciaCard(dynamic item, int index, bool isDark) {
    final estado = _normalizeEstado(item['estado']);
    final isPendiente = estado == 'pendiente';
    final double sueldo =
        double.tryParse(item['sueldo']?.toString() ?? '0') ?? 0.0;
    final double aporte =
        double.tryParse(item['aporte']?.toString() ?? '0') ?? 0.0;
    final double total =
        double.tryParse(item['total']?.toString() ?? '0') ?? (sueldo - aporte);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.gray700Color
                      : AppTheme.lightBorderColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPendiente
                      ? (isDark
                            ? const Color(0x3310B981)
                            : AppTheme.successLightBg)
                      : (isDark
                            ? const Color(0x333B82F6)
                            : AppTheme.infoLightBg),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  isPendiente ? 'Por cobrar' : 'Cobrado',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPendiente
                        ? (isDark
                              ? AppTheme.successColor
                              : AppTheme.successDarkColor)
                        : (isDark
                              ? AppTheme.infoColor
                              : AppTheme.infoDarkColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(item['fecha']),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              if (item['hora'] != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  item['hora'].toString().substring(0, 5),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    'Sueldo',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(sueldo),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Aporte',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '-${_formatCurrency(aporte)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(total),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item['fecha_pago'] != null && !isPendiente) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pagado: ${_formatDate(item['fecha_pago'])}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGratificacionCard(dynamic item, int index, bool isDark) {
    final estado = _normalizeEstado(item['estado']);
    final isPendiente = estado == 'pendiente';
    final double monto =
        double.tryParse(item['monto']?.toString() ?? '0') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.gray700Color
                      : AppTheme.lightBorderColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPendiente
                      ? (isDark
                            ? const Color(0x3310B981)
                            : AppTheme.successLightBg)
                      : (isDark
                            ? const Color(0x333B82F6)
                            : AppTheme.infoLightBg),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  isPendiente ? 'Por cobrar' : 'Cobrado',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPendiente
                        ? (isDark
                              ? AppTheme.successColor
                              : AppTheme.successDarkColor)
                        : (isDark
                              ? AppTheme.infoColor
                              : AppTheme.infoDarkColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (item['descripcion'] != null &&
              item['descripcion'].toString().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF222225)
                    : const Color(0xFFF9F9FB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '“${item['descripcion']}”',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(item['fecha_hora']),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              if (item['fecha_hora'] != null &&
                  item['fecha_hora'].toString().contains(' ')) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  item['fecha_hora'].toString().split(' ')[1].substring(0, 5),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monto Otorgado',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              Text(
                _formatCurrency(monto),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation(bool isDark) {
    final monthLabel = DateFormat('MMMM yyyy', 'es_ES').format(_currentDate);
    final monthFormatted = monthLabel[0].toUpperCase() + monthLabel.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => _navigateMonth(-1),
          ),
          GestureDetector(
            onTap: _goToCurrentMonth,
            child: Text(
              monthFormatted,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => _navigateMonth(1),
          ),
        ],
      ),
    );
  }
}
