import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../auth/data/auth_notifier.dart';
import 'widgets/attendance_code_display.dart';
import 'widgets/active_service_card.dart';
import 'widgets/service_detail_modal.dart';
import '../../auth/presentation/widgets/registro_asistencia_modal.dart';

class AnfitrionaHomeScreen extends ConsumerStatefulWidget {
  const AnfitrionaHomeScreen({super.key});

  @override
  ConsumerState<AnfitrionaHomeScreen> createState() => _AnfitrionaHomeScreenState();
}

class _AnronHomeData {
  final Map<String, dynamic> stats;
  final dynamic activeService;
  final int userStatus;
  final bool isLoading;
  final String? error;

  _AnronHomeData({
    this.stats = const {'totalEarnings': 0, 'svcCount': 0},
    this.activeService,
    this.userStatus = 1,
    this.isLoading = false,
    this.error,
  });

  _AnronHomeData copyWith({
    Map<String, dynamic>? stats,
    dynamic activeService,
    bool nullActiveService = false,
    int? userStatus,
    bool? isLoading,
    String? error,
  }) {
    return _AnronHomeData(
      stats: stats ?? this.stats,
      activeService: nullActiveService ? null : (activeService ?? this.activeService),
      userStatus: userStatus ?? this.userStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class _AnfitrionaHomeScreenState extends ConsumerState<AnfitrionaHomeScreen> {
  _AnronHomeData _data = _AnronHomeData();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _data = _data.copyWith(isLoading: true, error: null);
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final authState = ref.read(authProvider);
      final user = authState.user;

      if (user == null) return;

      final responses = await Future.wait<Response<dynamic>>([
        apiClient.dio.get('/users/me/stats').catchError((e) => Response(requestOptions: RequestOptions(), data: {'success': false})),
        apiClient.dio.get('/servicios/user').catchError((e) => Response(requestOptions: RequestOptions(), data: {'success': false})),
        apiClient.dio.get('/users/status').catchError((e) => Response(requestOptions: RequestOptions(), data: {'success': false})),
      ]);

      final statsRes = responses[0].data;
      final servicesRes = responses[1].data;
      final statusRes = responses[2].data;

      Map<String, dynamic> stats = {'totalEarnings': 0, 'svcCount': 0};
      if (statsRes != null && statsRes['success'] == true && statsRes['data'] != null) {
        stats = Map<String, dynamic>.from(statsRes['data']);
      }

      dynamic activeService;
      if (servicesRes != null && servicesRes['success'] == true && servicesRes['data'] is List) {
        final List<dynamic> list = servicesRes['data'];
        activeService = list.firstWhere(
          (s) => int.tryParse(s['estado']?.toString() ?? '0') == 2,
          orElse: () => null,
        );
      }

      int userStatus = 1;
      if (statusRes != null && statusRes['success'] == true && statusRes['status'] != null) {
        userStatus = int.tryParse(statusRes['status']?.toString() ?? '1') ?? 1;
      }

      if (mounted) {
        setState(() {
          _data = _AnronHomeData(
            stats: stats,
            activeService: activeService,
            userStatus: userStatus,
            isLoading: false,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _data = _data.copyWith(
            isLoading: false,
            error: 'Error al conectar con el servidor',
          );
        });
      }
    }
  }

  Future<void> _solicitarServicio() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Solicitar Asistencia', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('¿Deseas solicitar asistencia general al cajero?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar', style: TextStyle(color: Color(0xFFD84315), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/notifications/assistance',
        data: {'type': 'Llamado'},
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Llamado enviado con éxito'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar la solicitud de asistencia'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'Disponible';
      case 2:
        return 'En Turno';
      case 3:
        return 'En Descanso';
      default:
        return 'Desconectada';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return const Color(0xFF10B981);
      case 2:
        return const Color(0xFFEF4444);
      case 3:
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final accentTheme = ref.watch(accentColorProvider);
    final accentColor = accentTheme.color;
    final gradientColors = accentTheme.gradient;
    final isDark = themeMode == ThemeMode.dark;

    
    final bg = isDark ? Colors.black : const Color(0xFFF3F4F6);
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF27272A) : Colors.grey.shade200;

    final double totalEarnings = double.tryParse(_data.stats['totalEarnings']?.toString() ?? '0') ?? 0.0;
    const double targetEarnings = 50000.0;
    final int percent = targetEarnings > 0 ? ((totalEarnings / targetEarnings) * 100).round().clamp(0, 100) : 0;

    final formatter = NumberFormat.simpleCurrency(decimalDigits: 0, name: 'CLP');

    final double paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Header Premium con Gradiente
          Container(
            padding: EdgeInsets.fromLTRB(20, paddingTop + 10, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Acciones Rápidas del Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // QR Scanner Button
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          RegistroAsistenciaModal.show(context, () {
                            _loadData();
                          });
                        },
                      ),
                    ),
                    // Perfil Settings Button
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                        onPressed: () => context.push('/anfitriona/perfil'),
                      ),
                    ),
                    // Theme Switcher Button
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isDark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          ref.read(themeModeProvider.notifier).state =
                              isDark ? ThemeMode.light : ThemeMode.dark;
                        },
                      ),
                    ),
                    // Logout Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          ref.read(authProvider.notifier).logout();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Perfil de Usuario Premium
                Row(
                  children: [
                    // Avatar Circular
                    GestureDetector(
                      onTap: () => context.push('/anfitriona/perfil'),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 2),
                          gradient: user?.foto.isNotEmpty == true
                              ? null
                              : const LinearGradient(
                                  colors: [Colors.white24, Colors.white12],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          image: user?.foto.isNotEmpty == true
                              ? DecorationImage(
                                  image: NetworkImage(
                                    user!.foto.startsWith('http')
                                        ? user.foto
                                        : '${ApiClient.baseUrl}/img/users/${user.foto}',
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: user?.foto.isNotEmpty == true
                            ? null
                            : Text(
                                user?.nombre.isNotEmpty == true ? user!.nombre[0].toUpperCase() : 'A',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 22,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Informacion de perfil
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@${user?.nombre.toLowerCase().replaceAll(' ', '') ?? 'anfitriona'}',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const AttendanceCodeDisplay(),
                            ],
                          ),
                          if (user?.nombre != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              user!.nombre,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Estado de disponibilidad
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_data.userStatus),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getStatusColor(_data.userStatus).withValues(alpha: 0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getStatusText(_data.userStatus),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Boton Solicitar Servicio integrado en Header (si no hay servicio activo)
                if (_data.activeService == null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: accentColor,
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.25),
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                        onPressed: _solicitarServicio,
                        child: Text(
                          'SOLICITAR SERVICIO',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: accentColor,
              backgroundColor: cardBg,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Active Service Card (si tiene habitacion asignada)
                  if (_data.activeService != null) ...[
                    ActiveServiceCard(
                      habitacion: _data.activeService['habitacion']?.toString() ?? '',
                      tiempoRestante: _data.activeService['tiempo_restante']?.toString(),
                      onPress: () {
                        ServiceDetailModal.show(
                          context: context,
                          servicio: _data.activeService,
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                  ],

                  // Analytics section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'RESUMEN FINANCIERO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: textSecondary.withValues(alpha: 0.8),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        // Weekly goal card
                        Expanded(
                          child: Card(
                            color: cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(color: borderColor),
                            ),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Meta Semanal',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: CircularProgressIndicator(
                                          value: percent / 100.0,
                                          strokeWidth: 6,
                                          backgroundColor: isDark ? const Color(0xFF27272A) : Colors.grey.shade100,
                                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                        ),
                                      ),
                                      Text(
                                        '$percent%',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '${formatter.format(totalEarnings)} / ${formatter.format(targetEarnings)}',
                                    style: GoogleFonts.inter(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Growth card
                        Expanded(
                          child: Card(
                            color: cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(color: borderColor),
                            ),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Crecimiento',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    '+12%',
                                    style: GoogleFonts.outfit(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Semana Actual',
                                    style: GoogleFonts.inter(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_data.error != null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        _data.error!,
                        style: TextStyle(color: Colors.redAccent.shade100),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
