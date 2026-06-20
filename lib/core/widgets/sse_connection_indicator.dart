import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sse_connection_status.dart';
import '../sse_event.dart';
import '../sse_service.dart';





class SseConnectionStatusListener extends ConsumerStatefulWidget {
  const SseConnectionStatusListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SseConnectionStatusListener> createState() =>
      _SseConnectionStatusListenerState();
}

class _SseConnectionStatusListenerState
    extends ConsumerState<SseConnectionStatusListener> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SseEvent>>(sseEventStreamProvider, (prev, next) {
      next.whenData((event) {
        switch (event.type) {
          case 'connected':
            ref.read(sseConnectionStatusProvider.notifier).state =
                SseConnectionStatus.connected;
            break;
          case 'sse_disconnected':
            ref.read(sseConnectionStatusProvider.notifier).state =
                SseConnectionStatus.disconnected;
            break;
          case 'sse_reconnecting':
            ref.read(sseConnectionStatusProvider.notifier).state =
                SseConnectionStatus.reconnecting;
            break;
        }
      });
      if (next.hasError) {
        ref.read(sseConnectionStatusProvider.notifier).state =
            SseConnectionStatus.disconnected;
      }
    });
    return widget.child;
  }
}






class SseConnectionIndicator extends ConsumerStatefulWidget {
  const SseConnectionIndicator({super.key});

  @override
  ConsumerState<SseConnectionIndicator> createState() =>
      _SseConnectionIndicatorState();
}

class _SseConnectionIndicatorState
    extends ConsumerState<SseConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _autoHideTimer;

  Color _dotColor = const Color(0xFF10B981);
  String _label = 'SSE Conectado';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SseConnectionStatus>(sseConnectionStatusProvider, (_, next) {
      _autoHideTimer?.cancel();

      switch (next) {
        case SseConnectionStatus.connected:
          _pulseController
            ..stop()
            ..value = 1.0;
          _dotColor = const Color(0xFF10B981);
          _label = 'SSE Conectado';
          _autoHideTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _pulseController
                ..stop()
                ..value = 0.0;
            }
          });
        case SseConnectionStatus.reconnecting:
          _dotColor = const Color(0xFFF59E0B);
          _label = 'SSE Reconectando...';
          _pulseController.repeat(reverse: true);
        case SseConnectionStatus.disconnected:
          _dotColor = const Color(0xFFEF4444);
          _label = 'SSE Desconectado';
          _pulseController.repeat(reverse: true);
      }
    });

    ref.watch(sseConnectionStatusProvider); 
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = _pulseController.isAnimating
            ? 0.4 + (_pulseController.value * 0.6)
            : _pulseController.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: _dotColor.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _dotColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _dotColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
