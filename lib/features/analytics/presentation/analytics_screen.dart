import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../data/analytics_notifier.dart';

/// Dashboard analítico con gráficos y estadísticas.
///
/// Espeja `AnalyticsDashboard.tsx` de Expo.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentTheme = ref.watch(accentColorProvider);

    final bg = isDark ? AppTheme.darkBgColor : const Color(0xFFF3F4F6);
    final cardBg = isDark ? AppTheme.darkSurfaceColor : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await ref.read(analyticsProvider.notifier).fetchData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(accentTheme),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error banner
                          if (state.error != null)
                            _buildErrorBanner(state.error!, accentTheme),

                          // Stat cards
                          _buildStatGrid(
                              state, accentTheme, cardBg, textPrimary, textSecondary, isDark),

                          const SizedBox(height: 28),

                          // Sales chart
                          _buildSectionTitle(
                              'Ventas Semanales', textPrimary),
                          const SizedBox(height: 12),
                          _buildBarChart(
                              state, accentTheme, cardBg, isDark, textSecondary),

                          const SizedBox(height: 28),

                          // Distribution pie
                          _buildSectionTitle(
                              'Distribución', textPrimary),
                          const SizedBox(height: 12),
                          _buildPieChart(
                              state, accentTheme, cardBg, textPrimary, textSecondary, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────

  Widget _buildHeader(dynamic accentTheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: accentTheme.gradient,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Analíticas',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error Banner ────────────────────────────────────────────────

  Widget _buildErrorBanner(String error, accentTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.warningColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mostrando datos demo — $error',
              style: GoogleFonts.inter(
                color: AppTheme.warningColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section title ───────────────────────────────────────────────

  Widget _buildSectionTitle(String title, Color textPrimary) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STAT CARDS (2x2 grid)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatGrid(
    AnalyticsState state,
    accentTheme,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final icons = [
      Icons.trending_up_rounded,
      Icons.miscellaneous_services_rounded,
      Icons.attach_money_rounded,
      Icons.card_giftcard_rounded,
    ];

    final colors = [
      accentTheme.color,
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: state.stats.length,
      itemBuilder: (context, index) {
        final stat = state.stats[index];
        return StaggeredFadeIn(
          index: index,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppTheme.darkBorderColor
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors[index].withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icons[index], color: colors[index], size: 18),
                ),
                const Spacer(),
                Text(
                  stat.title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stat.value,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BAR CHART (7-day sales)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBarChart(
    AnalyticsState state,
    accentTheme,
    Color cardBg,
    bool isDark,
    Color textSecondary,
  ) {
    final data = state.barData;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.fold<double>(
            0, (prev, d) => d.value > prev ? d.value : prev) *
        1.2;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '\$${(rod.toY / 1000).toStringAsFixed(1)}k',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: GoogleFonts.inter().fontFamily,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[idx].label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${(value / 1000).toStringAsFixed(0)}k',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark
                  ? AppTheme.darkBorderColor.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: d.value,
                  color: accentTheme.color,
                  width: 22,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      accentTheme.color,
                      accentTheme.color.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PIE CHART (distribution)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPieChart(
    AnalyticsState state,
    accentTheme,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final data = state.pieData;
    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.fold<double>(0, (prev, d) => prev + d.value);
    final pieColors = data
        .map((d) => Color(int.parse(d.color.replaceFirst('#', '0xFF'))))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Pie chart
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 32,
                sections: List.generate(data.length, (i) {
                  final pct = data[i].value / total;
                  return PieChartSectionData(
                    color: pieColors[i],
                    value: data[i].value,
                    title:
                        '${(pct * 100).toStringAsFixed(0)}%',
                    radius: 42,
                    titleStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
              duration: const Duration(milliseconds: 500),
            ),
          ),
          const SizedBox(width: 24),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(data.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: pieColors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data[i].label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _currencyFormat.format(data[i].value),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
