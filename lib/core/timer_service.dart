import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'sse_event.dart';
import 'sse_service.dart';


class ActiveTimer {
  final String id;
  final String servicioId;
  final String roomId;
  final String roomName;
  final int duration; 
  final int remainingTime; 
  final bool isActive;
  final bool isPaused;
  final DateTime? startTime;
  final String servicioCode;
  final String? clienteId;
  final String clienteNombre;
  final String? tipoTransaccion; 
  final String? anfitrionas;
  final double? precioServicio;
  final double? precioHabitacion;
  final double? iva;
  final double? total;
  final String? metodoPago;
  final String? waiterName;
  final String? solicitanteName;
  final double? habitacionComision;
  final List<String> anfitrionasIds;
  final String? createdAt;
  final int? estado;
  final int? totalUsuarios;
  final double? comisionIndividual;
  final bool esTemporal;
  final String? servicioOriginalId;

  ActiveTimer({
    required this.id,
    required this.servicioId,
    required this.roomId,
    required this.roomName,
    required this.duration,
    required this.remainingTime,
    required this.isActive,
    required this.isPaused,
    this.startTime,
    required this.servicioCode,
    this.clienteId,
    required this.clienteNombre,
    this.tipoTransaccion,
    this.anfitrionas,
    this.precioServicio,
    this.precioHabitacion,
    this.iva,
    this.total,
    this.metodoPago,
    this.waiterName,
    this.solicitanteName,
    this.habitacionComision,
    this.anfitrionasIds = const [],
    this.createdAt,
    this.estado,
    this.totalUsuarios,
    this.comisionIndividual,
    this.esTemporal = false,
    this.servicioOriginalId,
  });

  
  int calculateRemaining(int serverOffset) {
    if (isPaused || estado == 3) {
      return remainingTime;
    }
    if (startTime == null) return remainingTime;
    final now = DateTime.now().millisecondsSinceEpoch + serverOffset;
    final start = startTime!.millisecondsSinceEpoch;
    final elapsedSeconds = ((now - start) / 1000).floor();
    final totalSeconds = duration * 60;
    final remaining = totalSeconds - elapsedSeconds;
    
    if (remaining == 0 && duration > 0 && elapsedSeconds < 120) {
      return totalSeconds;
    }
    return remaining;
  }

  
  String formatRemaining(int serverOffset) {
    final remaining = calculateRemaining(serverOffset);
    if (remaining <= 0 && (isPaused || estado == 3)) {
      final m = duration;
      return '$m:00';
    }
    final abs = remaining.abs();
    final m = abs ~/ 60;
    final s = abs % 60;
    final sign = remaining < 0 ? '-' : '';
    return '$sign$m:${s.toString().padLeft(2, '0')}';
  }

  
  bool isOverdue(int serverOffset) {
    if (isPaused || estado == 3) return false;
    return calculateRemaining(serverOffset) <= 0;
  }

  factory ActiveTimer.fromJson(Map<String, dynamic> json) {
    final anfitrionasIdsRaw = json['anfitrionas_ids'];
    List<String> anfIds = [];
    if (anfitrionasIdsRaw is String) {
      anfIds = anfitrionasIdsRaw.split(',').where((s) => s.isNotEmpty).toList();
    } else if (anfitrionasIdsRaw is List) {
      anfIds = anfitrionasIdsRaw.map((e) => e.toString()).toList();
    }

    DateTime? parsedStart;
    if (json['startTime'] != null) {
      try {
        parsedStart = DateTime.parse(json['startTime'].toString()).toLocal();
      } catch (_) {}
    }

    return ActiveTimer(
      id: '${json['servicioId']}-${json['roomId']}',
      servicioId: json['servicioId']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
      duration: int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      remainingTime: int.tryParse(json['remainingTime']?.toString() ?? '0') ?? 0,
      isActive: true,
      isPaused: json['isPaused'] == 1 || json['estado'] == 3,
      startTime: parsedStart,
      servicioCode: json['codigo']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString(),
      clienteNombre: json['clienteNombre']?.toString() ?? '',
      tipoTransaccion: json['tipoTransaccion']?.toString(),
      anfitrionas: json['anfitrionas']?.toString(),
      precioServicio: double.tryParse(json['precio_servicio']?.toString() ?? ''),
      precioHabitacion: double.tryParse(json['precio_habitacion']?.toString() ?? ''),
      iva: double.tryParse(json['iva']?.toString() ?? ''),
      total: double.tryParse(json['total']?.toString() ?? ''),
      metodoPago: json['metodo_pago']?.toString(),
      waiterName: json['waiter_name']?.toString(),
      solicitanteName: json['solicitante_name']?.toString(),
      habitacionComision: double.tryParse(json['habitacion_comision']?.toString() ?? '0') ?? 0,
      anfitrionasIds: anfIds,
      createdAt: json['created_at']?.toString(),
      estado: int.tryParse(json['estado']?.toString() ?? ''),
      totalUsuarios: int.tryParse(json['total_usuarios']?.toString() ?? ''),
      comisionIndividual: double.tryParse(json['comision_individual']?.toString() ?? ''),
      esTemporal: json['es_temporal'] == 1 || json['es_temporal'] == true,
      servicioOriginalId: json['servicioOriginalId']?.toString(),
    );
  }
}


class TimerState {
  final List<ActiveTimer> timers;
  final int serverOffset;
  final bool loading;

  TimerState({
    this.timers = const [],
    this.serverOffset = 0,
    this.loading = true,
  });

  TimerState copyWith({
    List<ActiveTimer>? timers,
    int? serverOffset,
    bool? loading,
  }) {
    return TimerState(
      timers: timers ?? this.timers,
      serverOffset: serverOffset ?? this.serverOffset,
      loading: loading ?? this.loading,
    );
  }

  
  ActiveTimer? getTimer(String servicioId, {String? tipoTransaccion}) {
    try {
      return timers.firstWhere(
        (t) => t.servicioId == servicioId &&
            (tipoTransaccion == null || t.tipoTransaccion == tipoTransaccion),
      );
    } catch (_) {
      return null;
    }
  }

  
  ActiveTimer? getTimerForRoom(String roomId) {
    try {
      return timers.firstWhere((t) => t.roomId == roomId);
    } catch (_) {
      return null;
    }
  }

  
  List<ActiveTimer> getTimersByType(String tipo) {
    return timers.where((t) => t.tipoTransaccion == tipo).toList();
  }
}


class TimerNotifier extends StateNotifier<TimerState> {
  TimerNotifier() : super(TimerState()) {
    fetchActiveTimers();
    _startCountdown();
  }

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://dashboard.xn--lasmuecasderamon-bub.com/api',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  DateTime? _lastFetchTime;
  Timer? _countdownTimer;
  bool _isClosed = false;

  
  Future<void> fetchActiveTimers() async {
    
    if (_lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff.inSeconds < 2) return;
    }
    _lastFetchTime = DateTime.now();

    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '/timers/active?source=mobile',
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );

      final data = response.data;
      if (data['success'] == true && data['data'] is List) {
        int offset = state.serverOffset;
        if (data['serverTime'] != null) {
          try {
            final serverDate = DateTime.parse(data['serverTime'].toString());
            final localDate = DateTime.now();
            offset = serverDate.millisecondsSinceEpoch - localDate.millisecondsSinceEpoch;
          } catch (_) {}
        }

        final activeTimers = (data['data'] as List)
            .map((t) => ActiveTimer.fromJson(t))
            .toList();

        state = state.copyWith(
          timers: activeTimers,
          serverOffset: offset,
          loading: false,
        );
      }
    } catch (_) {
      
      if (!_isClosed) {
        Future.delayed(const Duration(seconds: 5), () {
          if (!_isClosed) fetchActiveTimers();
        });
      }
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  
  void handleSSEEvent(SseEvent event) {
    switch (event.type) {
      case 'timer_started':
        _handleTimerStarted(event.data);
        break;
      case 'timer_stopped':
        _handleTimerStopped(event.data);
        break;
      case 'timer_paused':
        _handleTimerPaused(event.data);
        break;
      case 'timer_resumed':
        _handleTimerResumed(event.data);
        break;
      case 'timer_updated':
        _handleTimerUpdated(event.data);
        break;
      case 'timers_updated':
        fetchActiveTimers();
        break;
    }
  }

  void _handleTimerStarted(Map<String, dynamic> data) {
    final newTimer = ActiveTimer.fromJson(data);
    final updated = [
      ...state.timers.where((t) =>
          !(t.servicioId == newTimer.servicioId &&
              t.tipoTransaccion == newTimer.tipoTransaccion)),
      newTimer,
    ];
    state = state.copyWith(timers: updated);
  }

  void _handleTimerStopped(Map<String, dynamic> data) {
    final servicioId = data['servicioId']?.toString() ?? '';
    final tipo = data['tipoTransaccion']?.toString() ?? 'servicio';
    state = state.copyWith(
      timers: state.timers
          .where((t) =>
              !(t.servicioId == servicioId && t.tipoTransaccion == tipo))
          .toList(),
    );
  }

  void _handleTimerPaused(Map<String, dynamic> data) {
    final servicioId = data['servicioId']?.toString() ?? '';
    final tipo = data['tipoTransaccion']?.toString() ?? 'servicio';
    state = state.copyWith(
      timers: state.timers.map((t) {
        if (t.servicioId == servicioId && t.tipoTransaccion == tipo) {
          return ActiveTimer(
            id: t.id,
            servicioId: t.servicioId,
            roomId: t.roomId,
            roomName: t.roomName,
            duration: t.duration,
            remainingTime: t.calculateRemaining(state.serverOffset),
            isActive: t.isActive,
            isPaused: true,
            startTime: t.startTime,
            servicioCode: t.servicioCode,
            clienteId: t.clienteId,
            clienteNombre: t.clienteNombre,
            tipoTransaccion: t.tipoTransaccion,
            anfitrionas: t.anfitrionas,
            precioServicio: t.precioServicio,
            precioHabitacion: t.precioHabitacion,
            iva: t.iva,
            total: t.total,
            metodoPago: t.metodoPago,
            waiterName: t.waiterName,
            solicitanteName: t.solicitanteName,
            habitacionComision: t.habitacionComision,
            anfitrionasIds: t.anfitrionasIds,
            createdAt: t.createdAt,
            estado: 3,
            totalUsuarios: t.totalUsuarios,
            comisionIndividual: t.comisionIndividual,
            esTemporal: t.esTemporal,
            servicioOriginalId: t.servicioOriginalId,
          );
        }
        return t;
      }).toList(),
    );
  }

  void _handleTimerResumed(Map<String, dynamic> data) {
    final servicioId = data['servicioId']?.toString() ?? '';
    final tipo = data['tipoTransaccion']?.toString() ?? 'servicio';
    final newStartTime = data['newStartTime'] != null
        ? DateTime.tryParse(data['newStartTime'].toString())?.toLocal()
        : null;

    state = state.copyWith(
      timers: state.timers.map((t) {
        if (t.servicioId == servicioId && t.tipoTransaccion == tipo) {
          return ActiveTimer(
            id: t.id,
            servicioId: t.servicioId,
            roomId: t.roomId,
            roomName: t.roomName,
            duration: t.duration,
            remainingTime: t.duration * 60,
            isActive: t.isActive,
            isPaused: false,
            startTime: newStartTime ?? t.startTime,
            servicioCode: t.servicioCode,
            clienteId: t.clienteId,
            clienteNombre: t.clienteNombre,
            tipoTransaccion: t.tipoTransaccion,
            anfitrionas: t.anfitrionas,
            precioServicio: t.precioServicio,
            precioHabitacion: t.precioHabitacion,
            iva: t.iva,
            total: t.total,
            metodoPago: t.metodoPago,
            waiterName: t.waiterName,
            solicitanteName: t.solicitanteName,
            habitacionComision: t.habitacionComision,
            anfitrionasIds: t.anfitrionasIds,
            createdAt: t.createdAt,
            estado: 2,
            totalUsuarios: t.totalUsuarios,
            comisionIndividual: t.comisionIndividual,
            esTemporal: t.esTemporal,
            servicioOriginalId: t.servicioOriginalId,
          );
        }
        return t;
      }).toList(),
    );
  }

  void _handleTimerUpdated(Map<String, dynamic> data) {
    final servicioId = data['servicioId']?.toString() ?? '';
    final tipo = data['tipoTransaccion']?.toString() ?? 'servicio';
    state = state.copyWith(
      timers: state.timers.map((t) {
        if (t.servicioId == servicioId && t.tipoTransaccion == tipo) {
          
          final updatedJson = <String, dynamic>{
            'servicioId': t.servicioId,
            'roomId': t.roomId,
            'roomName': data['roomName'] ?? t.roomName,
            'duration': data['duration'] ?? t.duration,
            'startTime': data['startTime'] ?? t.startTime?.toIso8601String(),
            'codigo': t.servicioCode,
            'cliente_id': t.clienteId,
            'clienteNombre': t.clienteNombre,
            'tipoTransaccion': t.tipoTransaccion,
            'anfitrionas': data['anfitrionas'] ?? t.anfitrionas,
            'anfitrionas_ids': data['anfitrionas_ids'] ?? t.anfitrionasIds.join(','),
            'precio_servicio': t.precioServicio,
            'precio_habitacion': t.precioHabitacion,
            'iva': t.iva,
            'total': t.total,
            'metodo_pago': t.metodoPago,
            'waiter_name': t.waiterName,
            'habitacion_comision': t.habitacionComision,
            'created_at': t.createdAt,
            'estado': t.estado,
            'total_usuarios': t.totalUsuarios,
            'comision_individual': t.comisionIndividual,
          };
          return ActiveTimer.fromJson(updatedJson);
        }
        return t;
      }).toList(),
    );
  }

  
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isClosed && mounted) {
        
        state = state.copyWith();
      }
    });
  }

  Future<String?> _getAuthToken() async {
    try {
      const storage = FlutterSecureStorage();
      return await storage.read(key: 'auth_token');
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _isClosed = true;
    _countdownTimer?.cancel();
    super.dispose();
  }
}


final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  final notifier = TimerNotifier();

  
  final sseAsync = ref.watch(sseEventStreamProvider);
  sseAsync.whenData((event) {
    if (event.type.startsWith('timer_') || event.type == 'timers_updated') {
      notifier.handleSSEEvent(event);
    }
  });

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});


final timerForRoomProvider = Provider.family<ActiveTimer?, String>((ref, roomId) {
  final timerState = ref.watch(timerProvider);
  return timerState.getTimerForRoom(roomId);
});


final timersByTypeProvider = Provider.family<List<ActiveTimer>, String>((ref, tipo) {
  final timerState = ref.watch(timerProvider);
  return timerState.getTimersByType(tipo);
});


