import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class HorasExtrasScreen extends ConsumerStatefulWidget {
  const HorasExtrasScreen({super.key});

  @override
  ConsumerState<HorasExtrasScreen> createState() => _HorasExtrasScreenState();
}

class _HorasExtrasScreenState extends ConsumerState<HorasExtrasScreen> {
  String _filter = 'all'; 
  List<dynamic> _horasExtras = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
  }

  Future<void> _fetchData({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('horas_extras').notifier);
    notifier.startRefresh(isManual: isManual);

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/overtime/user');

      List<dynamic> list = [];
      if (response.data != null && response.data['success'] == true) {
        list = response.data['data'] ?? [];
      } else if (response.data is List) {
        list = response.data;
      }

      if (!mounted) return;
      setState(() => _horasExtras = list);
      notifier.endRefresh();

      if (isManual) notifier.showSuccessSnack(context, 'Horas extras actualizadas');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredData = _horasExtras.where((item) {
      final estado = item['estado']?.toString();
      if (_filter == 'pendiente') return estado == '1';
      if (_filter == 'pagado') return estado == '0';
      return true;
    }).toList();

    
    final pendientes = _horasExtras.where(
      (a) => a['estado']?.toString() == '1',
    );
    final double totalPendiente = pendientes.fold(
      0.0,
      (sum, item) =>
          sum +
          (double.tryParse(
                item['total']?.toString() ?? item['monto']?.toString() ?? '0',
              ) ??
              0.0),
    );

    final refresh = ref.watch(refreshProvider('horas_extras'));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Horas Extras',
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
                    StaggeredFadeIn(
                      children: [
                        
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceColor
                                : AppTheme.lightSurfaceColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkBorderColor
                                  : AppTheme.lightBorderColor,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'TOTAL PENDIENTE',
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
                                _formatCurrency(totalPendiente),
                                style: GoogleFonts.inter(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${pendientes.length} pendientes de ${_horasExtras.length} registros',
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
                        ),
                        const SizedBox(height: 16),

                        
                        Row(
                          children: [
                            _buildFilterButton(
                              'all',
                              'Todas (${_horasExtras.length})',
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              'pendiente',
                              'Pendientes (${_horasExtras.where((a) => a['estado']?.toString() == '1').length})',
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              'pagado',
                              'Cobradas (${_horasExtras.where((a) => a['estado']?.toString() == '0').length})',
                              isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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
                                  Icons.more_time_rounded,
                                  size: 48,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No se encontraron horas extras registradas',
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
                              return _buildOvertimeCard(item, index, isDark);
                            },
                          ),
                      ],
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
            const SkeletonCard(lines: 3),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: SkeletonCard(lines: 1)),
                SizedBox(width: 8),
                Expanded(child: SkeletonCard(lines: 1)),
                SizedBox(width: 8),
                Expanded(child: SkeletonCard(lines: 1)),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(4, (i) => const SkeletonCard(lines: 3)),
          ],
        ),
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

  Widget _buildOvertimeCard(dynamic item, int index, bool isDark) {
    final estado = item['estado']?.toString();
    final isPendiente = estado == '1';
    final double amount =
        double.tryParse(
          item['total']?.toString() ?? item['monto']?.toString() ?? '0',
        ) ??
        0.0;
    final hours = item['hora']?.toString() ?? '0';

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
                            ? const Color(0x33065F46)
                            : AppTheme.successLightBg)
                      : (isDark
                            ? AppTheme.infoColor.withValues(alpha: 0.2)
                            : AppTheme.infoLightBg),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  isPendiente ? 'Pendiente' : 'Cobrada',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPendiente
                        ? (isDark
                              ? AppTheme.successLightFg
                              : AppTheme.successDarkColor)
                        : (isDark
                              ? AppTheme.infoLightFg
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
                size: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(item['fecha_crea']),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '$hours hrs',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
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
                _formatCurrency(amount),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isPendiente
                      ? Theme.of(context).colorScheme.primary
                      : AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
