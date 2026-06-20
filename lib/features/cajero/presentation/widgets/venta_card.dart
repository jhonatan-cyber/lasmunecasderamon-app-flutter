import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme.dart';
import '../../../../core/timer_service.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../../../core/widgets/timer_pill.dart';
import '../../domain/venta_model.dart';
import 'venta_constants.dart';


class VentaCard extends ConsumerWidget {
  final Venta venta;
  final TimerState timerState;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onFinalizar;

  const VentaCard({
    super.key,
    required this.venta,
    required this.timerState,
    required this.isDark,
    required this.onTap,
    this.onFinalizar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = statusColor(venta.estado);
    final label = statusLabel(venta.estado);
    final isProceso = venta.estado == 2;
    final isAnulada = venta.estado == 0;

    
    ActiveTimer? activeTimer;
    try {
      activeTimer = timerState.timers.firstWhere(
        (t) => t.tipoTransaccion == 'venta' && t.servicioId == venta.idVenta.toString(),
      );
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Venta #${venta.idVenta}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isProceso && onFinalizar != null)
                            SizedBox(
                              height: 32,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.stop_circle_outlined, size: 14),
                                label: Text(
                                  'Finalizar',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: onFinalizar,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.person_outline_rounded,
                        venta.clienteNombre,
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.business_outlined,
                        venta.habitacionNombre ?? 'Barra / General',
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.access_time_rounded,
                        '${formatDateTime(venta.fechaCrea)} • ${venta.metodoPago}',
                        isDark,
                        small: true,
                      ),
                      if (activeTimer != null) ...[
                        const SizedBox(height: 8),
                        TimerPill(timer: activeTimer),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (venta.usuariosNicks != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${venta.usuariosNicks}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            formatCurrency(venta.total),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: isAnulada
                                  ? Colors.redAccent
                                  : (isDark ? Colors.white : Colors.black),
                              decoration:
                                  isAnulada ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String text,
    bool isDark, {
    bool small = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: small
                  ? (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
