import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/premium_fab.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/servicios_notifier.dart';

class ServiciosScreen extends ConsumerStatefulWidget {
  const ServiciosScreen({super.key});

  @override
  ConsumerState<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends ConsumerState<ServiciosScreen> {
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Defer to avoid Riverpod rebuild during mount cycle
    Future.microtask(
      () => ref.read(serviciosListProvider.notifier).fetchServicios(),
    );
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

  Future<void> _handleFinalizar(int idServicio, String roomName) async {
    final ok = await ref.read(serviciosListProvider.notifier).finalizarServicio(idServicio);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio finalizado correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(serviciosListProvider).error.isNotEmpty
              ? ref.read(serviciosListProvider).error
              : 'Error al finalizar servicio'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showFinalizarDialog(int idServicio, String roomName) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark
              ? AppTheme.darkSurfaceColor
              : AppTheme.lightSurfaceColor,
          title: Text(
            'Finalizar Servicio',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '¿Deseas finalizar el servicio de la habitación/mesa $roomName? Esto parará el reloj y liberará a la anfitriona.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await _handleFinalizar(idServicio, roomName);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                'Finalizar Servicio',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
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
          children: [...List.generate(5, (i) => const SkeletonCard(lines: 4))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(serviciosListProvider);

    // Filter active services (typically estado = 0 or in progress)
    final activeServicios = state.servicios
        .where((s) => (int.tryParse(s['estado']?.toString() ?? '0') ?? 0) == 0)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Servicios en Curso',
            showBackButton: true,
            onBack: () => context.pop(),
            showRefreshButton: true,
            isRefreshing: state.isRefreshing,
            onRefresh: () => ref.read(serviciosListProvider.notifier).fetchServicios(),
          ),
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: state.isLoading,
              skeleton: _buildSkeletonList(),
              content: RefreshIndicator(
                onRefresh: () => ref.read(serviciosListProvider.notifier).fetchServicios(),
                color: Theme.of(context).colorScheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.error.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.error,
                                  style: GoogleFonts.inter(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'Servicios Activos (${activeServicios.length})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (activeServicios.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 48,
                                  color: isDark
                                      ? AppTheme.darkBorderColor
                                      : AppTheme.lightBorderColor,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay servicios de acompañamiento activos',
                                  style: GoogleFonts.inter(
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
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
                            final int id =
                                int.tryParse(
                                  servicio['id_servicio']?.toString() ?? '',
                                ) ??
                                int.tryParse(
                                  servicio['id']?.toString() ?? '',
                                ) ??
                                0;
                            final roomName =
                                servicio['room_name'] ?? 'Sin Habitación';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Hab: $roomName',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.timer_outlined,
                                                      size: 10,
                                                      color:
                                                          Theme.of(context).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatElapsedTime(
                                                        servicio['fecha_inicio'],
                                                      ),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppTheme
                                                            .primaryColor,
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
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            'Cliente: ${servicio['cliente_nombre'] ?? 'Cliente General'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppTheme.darkTextSecondary
                                                  : AppTheme.lightTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent
                                            .withValues(alpha: 0.15),
                                        foregroundColor: Colors.redAccent,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showFinalizarDialog(id, roomName),
                                      child: Text(
                                        'Finalizar',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
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
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: PremiumFAB(
        icon: const Icon(Icons.add_alarm_rounded),
        onPressed: () => context.push('/cajero/servicios/nuevo'),
      ),
    );
  }
}
