import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/sse_service.dart';
import '../../../../core/sse_event.dart';
import '../../../auth/data/auth_notifier.dart';

class StaffCall {
  final String id;
  final String anfitrionaId;
  final String anfitrionaNombre;
  final String anfitrionaNick;
  final String roomName;
  final String assistanceType;
  final String? message;
  final String timestamp;

  StaffCall({
    required this.id,
    required this.anfitrionaId,
    required this.anfitrionaNombre,
    required this.anfitrionaNick,
    required this.roomName,
    required this.assistanceType,
    this.message,
    required this.timestamp,
  });

  factory StaffCall.fromMap(Map<String, dynamic> item) {
    Map<String, dynamic> parsedData = {};
    final rawData = item['data'] ?? item['datos'];

    if (rawData is String) {
      try {
        parsedData = jsonDecode(rawData) as Map<String, dynamic>;
      } catch (_) {
        parsedData = {};
      }
    } else if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData);
    }

    return StaffCall(
      id: item['id']?.toString() ?? item['id_notificacion']?.toString() ?? '',
      anfitrionaId: item['anfitriona_id']?.toString() ??
          item['usuario_id']?.toString() ??
          parsedData['anfitriona_id']?.toString() ??
          '',
      anfitrionaNombre: item['anfitriona_nombre'] ?? item['titulo'] ?? 'Anfitriona',
      anfitrionaNick: item['anfitriona_nick'] ??
          parsedData['anfitriona_nick'] ??
          item['titulo'] ??
          'Anfitriona',
      roomName: item['habitacion_nombre'] ?? parsedData['roomName'] ?? 'N/A',
      assistanceType: item['tipo'] ?? parsedData['type'] ?? 'Asistencia',
      message: item['mensaje'] ?? parsedData['message'],
      timestamp: item['fecha_crea'] ?? item['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class StaffCallOverlay extends ConsumerStatefulWidget {
  const StaffCallOverlay({super.key});

  @override
  ConsumerState<StaffCallOverlay> createState() => _StaffCallOverlayState();
}

class _StaffCallOverlayState extends ConsumerState<StaffCallOverlay> {
  final List<StaffCall> _pendingCalls = [];
  String? _acceptingId;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchPending());
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _fetchPending() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    
    
    final isStaff = user.isGarzon || user.isCajeroOrAdmin;
    if (!isStaff) return;

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get('/notifications/pending');
      
      if (_isDisposed) return;

      if (res.data != null) {
        final data = res.data;
        final rawList = data['notifications'] ?? data['data'];
        if (rawList is List) {
          setState(() {
            _pendingCalls.clear();
            _pendingCalls.addAll(rawList.map((x) => StaffCall.fromMap(Map<String, dynamic>.from(x))));
          });
        }
      }
    } catch (_) {
      
    }
  }

  Future<void> _handleAccept(StaffCall call) async {
    final user = ref.read(authProvider).user;
    if (user == null || _acceptingId != null) return;

    setState(() {
      _acceptingId = call.id;
    });

    try {
      final client = ref.read(apiClientProvider);
      final now = DateTime.now();
      final atendidoPorNombre = user.nombre.trim().isNotEmpty ? user.nombre.trim() : 'Staff';

      final res = await client.dio.post(
        '/notifications/assistance/accept',
        data: {
          'id': call.id,
          'estado': 'atendido',
          'atendido_por_id': user.id,
          'atendido_por_nombre': atendidoPorNombre,
          'fecha_atencion': DateFormat('yyyy-MM-dd').format(now),
          'hora_atencion': DateFormat('HH:mm:ss').format(now),
          'atendido_en': now.toIso8601String(),
        },
      );

      if (_isDisposed) return;

      final success = res.data?['success'] == true;
      if (success) {
        setState(() {
          _pendingCalls.removeWhere((c) => c.id == call.id);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Llamado atendido por $atendidoPorNombre',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      } else {
        final msg = res.data?['message'] ?? 'Error al aceptar llamado';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
        setState(() {
          _pendingCalls.removeWhere((c) => c.id == call.id);
        });
      }
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Error de conexión al aceptar llamado', style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
    } finally {
      if (!_isDisposed) {
        setState(() {
          _acceptingId = null;
        });
      }
    }
  }

  void _listenSseEvents(SseEvent event) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final isStaff = user.isGarzon || user.isCajeroOrAdmin;
    final isHostess = user.isHostess;

    if (!isStaff && !isHostess) return;

    
    if ((event.type == 'staff_call' || event.type == 'assistance_request') && isStaff) {
      final itemMap = Map<String, dynamic>.from(event.data);
      final callData = event.type == 'assistance_request'
          ? StaffCall.fromMap(Map<String, dynamic>.from(itemMap['datos'] ?? itemMap['data'] ?? itemMap))
          : StaffCall.fromMap(itemMap);

      final exists = _pendingCalls.any((c) => c.id == callData.id);
      if (!exists) {
        setState(() {
          _pendingCalls.insert(0, callData);
        });
        HapticFeedback.vibrate();
      }
    }

    
    else if (event.type == 'staff_call_accepted' && isStaff) {
      final callId = event.data['id']?.toString() ?? '';
      if (callId.isNotEmpty) {
        setState(() {
          _pendingCalls.removeWhere((c) => c.id == callId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    
    final isStaff = user.isGarzon || user.isCajeroOrAdmin;

    
    ref.listen<AsyncValue<SseEvent>>(sseEventStreamProvider, (prev, next) {
      next.whenData((event) {
        _listenSseEvents(event);
      });
    });

    if (!isStaff || _pendingCalls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 50.0,
      left: 16.0,
      right: 16.0,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _pendingCalls.map((call) => _buildCallCard(call)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCallCard(StaffCall call) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final isAcceptingThis = _acceptingId == call.id;

    return Container(
      key: ValueKey(call.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE11D48), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFE11D48),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOLICITUD DE PERSONAL',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${call.anfitrionaNick} • ${call.roomName != 'N/A' ? "Hab: ${call.roomName}" : "Salón"}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              call.message != null && call.message!.isNotEmpty
                  ? '${call.assistanceType}: ${call.message}'
                  : call.assistanceType,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
              onPressed: _acceptingId != null ? null : () => _handleAccept(call),
              child: isAcceptingThis
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'ACEPTAR Y ATENDER',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
