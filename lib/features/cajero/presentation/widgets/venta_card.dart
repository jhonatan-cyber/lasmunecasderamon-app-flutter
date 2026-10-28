import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/timer_service.dart';
import '../../../../core/widgets/currency_text.dart';
import 'venta_format.dart';

/// Tarjeta de una venta del listado (cajero): estado, cliente, habitación,
/// temporizador activo y total. Extraída de `ventas_screen.dart`.
class VentaCard extends StatelessWidget {
  const VentaCard({
    super.key,
    required this.venta,
    required this.isDark,
    required this.timerState,
    required this.onTap,
    required this.onFinalizar,
  });

  /// Fila cruda de `GET /sales` (mismo shape dinámico que usa el módulo).
  final dynamic venta;
  final bool isDark;
  final TimerState timerState;

  /// Abre el sheet «Opciones de Venta».
  final VoidCallback onTap;

  /// Muestra la confirmación de finalización (solo estado 2).
  final VoidCallback onFinalizar;

  @override
  Widget build(BuildContext context) {
    final int estado = int.tryParse(venta['estado']?.toString() ?? '1') ?? 1;
    final double total =
        double.tryParse(venta['total']?.toString() ?? '0') ?? 0.0;
    final method = venta['metodo_pago']?.toString().toUpperCase() ?? 'EFECTIVO';
    final ventaId = venta['id_venta']?.toString() ?? '';
    final isProceso = estado == 2;

    ActiveTimer? activeTimer;
    try {
      activeTimer = timerState.timers.firstWhere(
        (t) => t.tipoTransaccion == 'venta' && t.servicioId == ventaId,
      );
    } catch (_) {}

    Color statusColor;
    String statusLabel;
    switch (estado) {
      case 2:
        statusColor = Colors.orange;
        statusLabel = 'En proceso';
        break;
      case 3:
        statusColor = Colors.redAccent;
        statusLabel = 'Pdte. Anulación';
        break;
      case 0:
        statusColor = Colors.redAccent;
        statusLabel = 'Anulada';
        break;
      default:
        statusColor = Colors.green;
        statusLabel = 'Completado';
    }

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
                  color: statusColor,
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
                                'Venta #${venta['id_venta']}',
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
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isProceso)
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
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 14,
                                ),
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
                      _InfoRow(
                        Icons.person_outline_rounded,
                        venta['cliente_nombre'] ?? 'Cliente General',
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        Icons.business_outlined,
                        venta['habitacion_nombre'] ?? 'Barra / General',
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        Icons.access_time_rounded,
                        '${formatVentaDateTime(venta['fecha_crea'])} • $method',
                        isDark,
                        small: true,
                      ),
                      if (activeTimer != null) ...[
                        const SizedBox(height: 8),
                        _TimerPill(timer: activeTimer, timerState: timerState),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (venta['usuarios_nicks'] != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${venta['usuarios_nicks']}',
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
                            formatCurrency(total),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: estado == 0
                                  ? Colors.redAccent
                                  : (isDark ? Colors.white : Colors.black),
                              decoration: estado == 0
                                  ? TextDecoration.lineThrough
                                  : null,
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text, this.isDark, {this.small = false});

  final IconData icon;
  final String text;
  final bool isDark;
  final bool small;

  @override
  Widget build(BuildContext context) {
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
                  ? (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary)
                  : (isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Píldora del temporizador de una venta en proceso. Se refresca cada segundo
/// **ella sola**: antes la pantalla completa corría un `Timer.periodic(1s)`
/// con `setState` solo para mover esta cuenta regresiva, reconstruyendo la
/// lista entera cada segundo.
class _TimerPill extends StatefulWidget {
  const _TimerPill({required this.timer, required this.timerState});

  final ActiveTimer timer;
  final TimerState timerState;

  @override
  State<_TimerPill> createState() => _TimerPillState();
}

class _TimerPillState extends State<_TimerPill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    final timerState = widget.timerState;
    final remaining = timer.calculateRemaining(timerState.serverOffset);
    final isOverdue = timer.isOverdue(timerState.serverOffset);
    final isPaused = timer.isPaused;

    Color bgColor;
    Color textColor;
    String text;

    if (isOverdue) {
      bgColor = Colors.redAccent.withValues(alpha: 0.15);
      textColor = Colors.redAccent;
      text = 'AGOTADO';
    } else if (isPaused) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange;
      text = 'PAUSADO ${timer.formatRemaining(timerState.serverOffset)}';
    } else if (remaining <= 300) {
      bgColor = Colors.redAccent.withValues(alpha: 0.12);
      textColor = Colors.redAccent;
      text = timer.formatRemaining(timerState.serverOffset);
    } else {
      bgColor = Colors.green.withValues(alpha: 0.12);
      textColor = Colors.green;
      text = timer.formatRemaining(timerState.serverOffset);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? Icons.timer_off_rounded
                : isPaused
                ? Icons.pause_circle_outline
                : Icons.timer_outlined,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RESTANTE',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
