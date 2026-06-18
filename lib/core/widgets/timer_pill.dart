import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../timer_service.dart';

/// A compact pill-shaped widget that displays the remaining time for a timer.
/// Used in Ventas and Servicios lists to show real-time countdown.
class TimerPill extends ConsumerWidget {
  final ActiveTimer timer;

  const TimerPill({super.key, required this.timer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final remaining = timer.calculateRemaining(timerState.serverOffset);
    final isOverdue = timer.isOverdue(timerState.serverOffset);
    final isPaused = timer.isPaused;

    final Color bgColor;
    final Color textColor;
    final String text;

    if (isOverdue) {
      bgColor = Colors.redAccent.withValues(alpha: 0.2);
      textColor = Colors.redAccent;
      text = 'AGOTADO';
    } else if (isPaused) {
      bgColor = Colors.orange.withValues(alpha: 0.2);
      textColor = Colors.orange;
      text = 'PAUSADO ${timer.formatRemaining(timerState.serverOffset)}';
    } else if (remaining <= 300) {
      // Less than 5 minutes - urgent
      bgColor = Colors.redAccent.withValues(alpha: 0.15);
      textColor = Colors.redAccent;
      text = timer.formatRemaining(timerState.serverOffset);
    } else if (remaining <= 600) {
      // Less than 10 minutes - warning
      bgColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange;
      text = timer.formatRemaining(timerState.serverOffset);
    } else {
      bgColor = Colors.green.withValues(alpha: 0.15);
      textColor = Colors.green;
      text = timer.formatRemaining(timerState.serverOffset);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
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
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A standalone countdown timer widget used in CuentaTimer and other detail views.
class CuentaTimerWidget extends ConsumerWidget {
  final ActiveTimer timer;
  final double fontSize;

  const CuentaTimerWidget({
    super.key,
    required this.timer,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final remaining = timer.calculateRemaining(timerState.serverOffset);
    final isOverdue = remaining <= 0;

    final m = (remaining.abs() ~/ 60);
    final s = (remaining.abs() % 60);
    final formatted = '${remaining < 0 ? "-" : ""}$m:${s.toString().padLeft(2, "0")}';

    return Text(
      isOverdue ? 'AGOTADO' : formatted,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w900,
        color: isOverdue ? Colors.redAccent : Theme.of(context).colorScheme.primary,
        fontSize: fontSize,
      ),
    );
  }
}
