import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class ServiciosScreen extends ConsumerStatefulWidget {
  const ServiciosScreen({super.key});

  @override
  ConsumerState<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends ConsumerState<ServiciosScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _servicios = [];
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchServicios();
    // Refresh active timers on the UI every second
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchServicios({bool isManual = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = !isManual;
      _error = '';
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/servicios?all=true');

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        setState(() {
          _servicios = response.data['data'] ?? [];
          _loading = false;
        });

        if (isManual) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servicios actualizados'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Error al cargar los servicios';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexión al cargar servicios';
        _loading = false;
      });
    }
  }

  String _formatElapsedTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '00:00:00';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(parsed);
      if (diff.isNegative) return '00:00:00';

      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    } catch (_) {
      return '00:00:00';
    }
  }

  Future<void> _finalizarServicio(int idServicio) async {
    final client = ref.read(apiClientProvider);
    try {
      final response = await client.dio.patch(
        '/servicios/$idServicio',
        data: {
          'estado': 1, // Finalizado
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio finalizado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchServicios();
      } else {
        final msg = response.data?['message'] ?? 'Error al finalizar servicio';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al finalizar servicio'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showFinalizarDialog(int idServicio, String roomName) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          title: Text('Finalizar Servicio', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text(
            '¿Deseas finalizar el servicio de la habitación/mesa $roomName? Esto parará el reloj y liberará a la anfitriona.',
            style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await _finalizarServicio(idServicio);
                navigator.pop();
              },
              child: Text('Finalizar Servicio', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...List.generate(5, (i) => const SkeletonCard(lines: 4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter active services (typically estado = 0 or in progress)
    final activeServicios = _servicios.where((s) => (int.tryParse(s['estado']?.toString() ?? '0') ?? 0) == 0).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        elevation: 0,
        title: Text(
          'Servicios en Curso',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: () => _fetchServicios(isManual: true),
          ),
        ],
      ),
      body: FadeLoadingSwitcher(
        isLoading: _loading,
        skeleton: _buildSkeletonList(),
        content: RefreshIndicator(
              onRefresh: () => _fetchServicios(isManual: true),
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error,
                                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'Servicios Activos (${activeServicios.length})',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (activeServicios.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0),
                          child: Column(
                            children: [
                              Icon(Icons.hourglass_empty_rounded, size: 48, color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                              const SizedBox(height: 8),
                              Text(
                                'No hay servicios de acompañamiento activos',
                                style: GoogleFonts.inter(
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeServicios.length,
                        itemBuilder: (context, index) {
                          final servicio = activeServicios[index];
                          final int id = int.tryParse(servicio['id_servicio']?.toString() ?? '') ??
                              int.tryParse(servicio['id']?.toString() ?? '') ?? 0;
                          final roomName = servicio['room_name'] ?? 'Sin Habitación';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Hab: $roomName',
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.timer_outlined, size: 10, color: AppTheme.primaryColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatElapsedTime(servicio['fecha_inicio']),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Anfitriona: ${servicio['anfitriona_nombre'] ?? 'Ninguna'}',
                                          style: GoogleFonts.inter(fontSize: 13),
                                        ),
                                        Text(
                                          'Cliente: ${servicio['cliente_nombre'] ?? 'Cliente General'}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                                      foregroundColor: Colors.redAccent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _showFinalizarDialog(id, roomName),
                                    child: Text(
                                      'Finalizar',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
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
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_alarm_rounded),
        onPressed: () => context.push('/cajero/servicios/nuevo'),
      ),
    );
  }
}
