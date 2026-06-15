import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/timer_service.dart';

/// Global overlay that shows an alert dialog when a timer expires.
/// This should be placed at the top of the widget tree (like in the app's main scaffold).
class GlobalTimerAlert extends ConsumerStatefulWidget {
  const GlobalTimerAlert({super.key});

  @override
  ConsumerState<GlobalTimerAlert> createState() => _GlobalTimerAlertState();
}

class _GlobalTimerAlertState extends ConsumerState<GlobalTimerAlert> {
  String? _lastNotifiedId;

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);

    // Check for overdue timers that haven't been notified yet
    for (final timer in timerState.timers) {
      if (timer.isOverdue(timerState.serverOffset) &&
          timer.isActive &&
          !timer.isPaused &&
          _lastNotifiedId != timer.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showExpiredTimerAlert(timer);
        });
        break;
      }
    }

    return const SizedBox.shrink(); // Invisible widget
  }

  void _showExpiredTimerAlert(ActiveTimer timer) {
    if (!mounted) return;
    _lastNotifiedId = timer.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const Text('⏰', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    '¡Tiempo Terminado!',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timer.tipoTransaccion == 'servicio'
                        ? 'Servicio completado'
                        : timer.tipoTransaccion == 'venta'
                            ? 'Venta completada'
                            : 'Tiempo terminado',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFCA5A5),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildInfoRow('🛏️', 'Habitación', timer.roomName),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    '👤',
                    'Cliente',
                    timer.clienteNombre.isNotEmpty
                        ? timer.clienteNombre
                        : '—',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    timer.tipoTransaccion == 'venta' ? '🛒' : '🏠',
                    'Tipo',
                    timer.tipoTransaccion == 'servicio'
                        ? 'Servicio'
                        : timer.tipoTransaccion == 'venta'
                            ? 'Venta'
                            : '—',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    '⏱️',
                    'Duración',
                    '${timer.duration} minutos',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF333333)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Código:',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '#${timer.servicioCode}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF333333)),
                ),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // Refresh timers after dismissing
                  ref.read(timerProvider.notifier).fetchActiveTimers();
                },
                child: Text(
                  'Entendido',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
