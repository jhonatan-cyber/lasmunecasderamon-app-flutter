import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';






class GarzonDashboardState {
  final bool isLoading;
  final bool isRefreshing;
  final String error;
  final double totalEarnings;
  final int salesWithTips;
  final double payoutTotal;
  final List<Map<String, dynamic>> events;
  final Set<int> eventDays;

  GarzonDashboardState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error = '',
    this.totalEarnings = 0,
    this.salesWithTips = 0,
    this.payoutTotal = 0,
    this.events = const [],
    this.eventDays = const {},
  });

  GarzonDashboardState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    double? totalEarnings,
    int? salesWithTips,
    double? payoutTotal,
    List<Map<String, dynamic>>? events,
    Set<int>? eventDays,
    bool clearError = false,
  }) {
    return GarzonDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? '' : (error ?? this.error),
      totalEarnings: totalEarnings ?? this.totalEarnings,
      salesWithTips: salesWithTips ?? this.salesWithTips,
      payoutTotal: payoutTotal ?? this.payoutTotal,
      events: events ?? this.events,
      eventDays: eventDays ?? this.eventDays,
    );
  }
}





class GarzonDashboardNotifier extends StateNotifier<GarzonDashboardState> {
  final ApiClient _apiClient;

  GarzonDashboardNotifier(this._apiClient) : super(GarzonDashboardState());

  
  
  
  
  Future<void> fetchDashboardData({bool isManual = false}) async {
    if (!mounted) return;

    state = state.copyWith(
      isLoading: !isManual,
      isRefreshing: isManual,
      clearError: true,
    );

    try {
      final responses = await Future.wait<Response<dynamic>?>([
        _apiClient.dio
            .get('/events/user')
            .then<Response<dynamic>?>((r) => r)
            .catchError((_) => null),
        _apiClient.dio
            .get('/events/stats')
            .then<Response<dynamic>?>((r) => r)
            .catchError((_) => null),
        _apiClient.dio
            .get('/users/me/stats')
            .then<Response<dynamic>?>((r) => r)
            .catchError((_) => null),
      ]);

      if (!mounted) return;

      
      final eventsRes = responses[0];
      final List<Map<String, dynamic>> events = [];
      if (eventsRes != null && eventsRes.data != null) {
        final rawData = eventsRes.data;
        
        
        if (rawData is List) {
          for (final e in rawData) {
            events.add(Map<String, dynamic>.from(e));
          }
        } else if (rawData is Map) {
          final rawEvents = rawData['success'] == true
              ? rawData['data']
              : rawData;
          if (rawEvents is List) {
            for (final e in rawEvents) {
              events.add(Map<String, dynamic>.from(e));
            }
          }
        }
      }

      
      final statsRes = responses[1];
      double totalEarnings = 0;
      int salesWithTips = 0;
      if (statsRes != null && statsRes.data != null) {
        final statsData = statsRes.data['success'] == true
            ? statsRes.data['data']
            : statsRes.data;
        if (statsData is Map) {
          totalEarnings =
              double.tryParse(statsData['totalEarnings']?.toString() ?? '0') ??
                  0.0;
          salesWithTips =
              int.tryParse(statsData['svcCount']?.toString() ?? '0') ?? 0;
        }
      }

      
      final meStatsRes = responses[2];
      double payoutTotal = 0;
      if (meStatsRes != null && meStatsRes.data != null) {
        final data = meStatsRes.data['success'] == true
            ? meStatsRes.data['data']
            : meStatsRes.data;
        if (data is Map && data['stats'] is Map) {
          payoutTotal =
              double.tryParse(
                    data['stats']['montoAnticipoMaximo']?.toString() ?? '0',
                  ) ??
                  0.0;
        }
      }

      
      final Set<int> eventDays = {};
      final now = DateTime.now();
      for (final e in events) {
        final dateStr = e['date']?.toString();
        if (dateStr != null) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null &&
              parsed.year == now.year &&
              parsed.month == now.month) {
            eventDays.add(parsed.day);
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        totalEarnings: totalEarnings,
        salesWithTips: salesWithTips,
        payoutTotal: payoutTotal,
        events: events,
        eventDays: eventDays,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Error al cargar datos del dashboard',
      );
    }
  }
}





final garzonDashboardProvider = StateNotifierProvider.autoDispose<
    GarzonDashboardNotifier, GarzonDashboardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GarzonDashboardNotifier(apiClient);
});
