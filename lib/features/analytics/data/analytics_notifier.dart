import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/logger.dart';
import '../../auth/data/auth_notifier.dart';

/// Datos de una estadística individual.

/// Datos de una estadística individual.
class StatData {
  final String title;
  final String value;
  final String? subtitle;
  final String icon; // nombre del icono
  final double valueRaw;

  const StatData({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.valueRaw,
  });
}

/// Datos de un punto del gráfico de barras.
class BarChartDataPoint {
  final String label;
  final double value;

  const BarChartDataPoint({required this.label, required this.value});
}

/// Datos de un segmento del gráfico de torta.
class PieChartDataPoint {
  final String label;
  final double value;
  final String color;

  const PieChartDataPoint({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Estado completo del dashboard analítico.
class AnalyticsState {
  final List<StatData> stats;
  final List<BarChartDataPoint> barData;
  final List<PieChartDataPoint> pieData;
  final bool isLoading;
  final String? error;

  const AnalyticsState({
    this.stats = const [],
    this.barData = const [],
    this.pieData = const [],
    this.isLoading = false,
    this.error,
  });

  AnalyticsState copyWith({
    List<StatData>? stats,
    List<BarChartDataPoint>? barData,
    List<PieChartDataPoint>? pieData,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AnalyticsState(
      stats: stats ?? this.stats,
      barData: barData ?? this.barData,
      pieData: pieData ?? this.pieData,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final ApiClient _apiClient;

  AnalyticsNotifier(this._apiClient) : super(const AnalyticsState()) {
    fetchData();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.dio.get('/analytics/dashboard');
      final raw = response.data['data'] ?? response.data;

      // Parse stats from API or use demo data
      final stats = _parseStats(raw);
      final barData = _parseBarData(raw);
      final pieData = _parsePieData(raw);

      state = state.copyWith(
        stats: stats,
        barData: barData,
        pieData: pieData,
        isLoading: false,
      );
    } catch (e, stack) {
      Logger.captureException(e, hint: 'fetchAnalytics', stackTrace: stack);
      // Fallback: demo data for development
      state = state.copyWith(
        stats: _demoStats(),
        barData: _demoBarData(),
        pieData: _demoPieData(),
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ── Parsing helpers ─────────────────────────────────────────────

  List<StatData> _parseStats(Map<String, dynamic> raw) {
    try {
      final s = raw['stats'] as Map<String, dynamic>?;
      if (s == null) return _demoStats();
      return [
        StatData(
          title: 'Ventas',
          value: _fmt((s['total_ventas'] ?? 0).toDouble()),
          icon: 'trending_up',
          valueRaw: (s['total_ventas'] ?? 0).toDouble(),
        ),
        StatData(
          title: 'Servicios',
          value: _fmt((s['total_servicios'] ?? 0).toDouble()),
          icon: 'miscellaneous_services',
          valueRaw: (s['total_servicios'] ?? 0).toDouble(),
        ),
        StatData(
          title: 'Comisiones',
          value: _fmt((s['total_comisiones'] ?? 0).toDouble()),
          icon: 'attach_money',
          valueRaw: (s['total_comisiones'] ?? 0).toDouble(),
        ),
        StatData(
          title: 'Propinas',
          value: _fmt((s['total_propinas'] ?? 0).toDouble()),
          subtitle: 'Acumulado',
          icon: 'card_giftcard',
          valueRaw: (s['total_propinas'] ?? 0).toDouble(),
        ),
      ];
    } catch (_) {
      return _demoStats();
    }
  }

  List<BarChartDataPoint> _parseBarData(Map<String, dynamic> raw) {
    try {
      final days = raw['ventas_por_dia'] as List?;
      if (days == null || days.isEmpty) return _demoBarData();
      return days.map((d) {
        final map = d as Map<String, dynamic>;
        return BarChartDataPoint(
          label: map['dia']?.toString() ?? '',
          value: (map['total'] ?? 0).toDouble(),
        );
      }).toList();
    } catch (_) {
      return _demoBarData();
    }
  }

  List<PieChartDataPoint> _parsePieData(Map<String, dynamic> raw) {
    try {
      final dist = raw['distribucion'] as List?;
      if (dist == null || dist.isEmpty) return _demoPieData();
      final colors = ['#4F46E5', '#10B981', '#F59E0B', '#EF4444'];
      return dist.asMap().entries.map((e) {
        final map = e.value as Map<String, dynamic>;
        return PieChartDataPoint(
          label: map['nombre']?.toString() ?? '',
          value: (map['total'] ?? 0).toDouble(),
          color: colors[e.key % colors.length],
        );
      }).toList();
    } catch (_) {
      return _demoPieData();
    }
  }

  // ── Demo data (fallback cuando la API no existe) ───────────────

  List<StatData> _demoStats() => [
        const StatData(
            title: 'Ventas',
            value: '\$45,230',
            icon: 'trending_up',
            valueRaw: 45230),
        const StatData(
            title: 'Servicios',
            value: '\$12,450',
            subtitle: '+12% vs mes ant.',
            icon: 'miscellaneous_services',
            valueRaw: 12450),
        const StatData(
            title: 'Comisiones',
            value: '\$8,920',
            icon: 'attach_money',
            valueRaw: 8920),
        const StatData(
            title: 'Propinas',
            value: '\$3,150',
            subtitle: 'Acumulado',
            icon: 'card_giftcard',
            valueRaw: 3150),
      ];

  List<BarChartDataPoint> _demoBarData() => const [
        BarChartDataPoint(label: 'Lun', value: 5200),
        BarChartDataPoint(label: 'Mar', value: 4800),
        BarChartDataPoint(label: 'Mié', value: 6100),
        BarChartDataPoint(label: 'Jue', value: 5500),
        BarChartDataPoint(label: 'Vie', value: 7800),
        BarChartDataPoint(label: 'Sáb', value: 9200),
        BarChartDataPoint(label: 'Dom', value: 4300),
      ];

  List<PieChartDataPoint> _demoPieData() => const [
        PieChartDataPoint(
            label: 'Ventas', value: 45230, color: '#4F46E5'),
        PieChartDataPoint(
            label: 'Servicios', value: 12450, color: '#10B981'),
        PieChartDataPoint(
            label: 'Comisiones', value: 8920, color: '#F59E0B'),
        PieChartDataPoint(
            label: 'Propinas', value: 3150, color: '#EF4444'),
      ];

  static String _fmt(double v) {
    if (v >= 1000) {
      return '\$${(v / 1000).toStringAsFixed(1)}k';
    }
    return '\$${v.toStringAsFixed(0)}';
  }
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnalyticsNotifier(apiClient);
});
