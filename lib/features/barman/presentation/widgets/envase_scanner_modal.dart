import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/haptic_service.dart';

/// Veredicto de una lectura de envase (`ok` = entregado al almacén).
/// Espejo de `EnvaseVeredicto` de `useEnvasesScreen.ts` en la app Expo.
class EnvaseVeredicto {
  final bool ok;
  final String texto;

  const EnvaseVeredicto({required this.ok, required this.texto});
}

/// Pausa tras cada lectura para que la misma imagen no se relea en bucle.
const _cooldownMs = Duration(milliseconds: 1200);
/// Cuánto queda visible el veredicto antes de volver a escanear.
const _feedbackMs = Duration(milliseconds: 2500);

/// Escáner de envases con lectura continua.
///
/// Porte de `EnvaseScannerModal.tsx` de la app Expo: la cámara sigue abierta
/// para procesar varios envases seguidos y el veredicto de cada lectura se
/// muestra sobreimpreso (verde = entregado, rojo = rechazado) mientras la
/// detección queda en pausa un instante para no releer el mismo código.
class EnvaseScannerModal extends StatefulWidget {
  const EnvaseScannerModal({
    super.key,
    required this.onScanned,
    required this.onClose,
  });

  /// Procesa la lectura. Devuelve el veredicto para mostrarlo en pantalla, o
  /// `null` si no se procesó (error de red ya avisado; no entra en cooldown
  /// para que el siguiente intento sea inmediato).
  final Future<EnvaseVeredicto?> Function(String data) onScanned;
  final VoidCallback onClose;

  static Future<void> show(
    BuildContext context, {
    required Future<EnvaseVeredicto?> Function(String data) onScanned,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => EnvaseScannerModal(
          onScanned: onScanned,
          onClose: () => Navigator.of(context).pop(),
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  State<EnvaseScannerModal> createState() => _EnvaseScannerModalState();
}

class _EnvaseScannerModalState extends State<EnvaseScannerModal> {
  late final MobileScannerController _controller;
  Timer? _feedbackTimer;

  bool _busy = false;
  bool _cooldown = false;
  bool _torch = false;
  EnvaseVeredicto? _feedback;

  @override
  void initState() {
    super.initState();
    // detectionSpeed.noDuplicates evita lecturas repetidas del mismo fotograma;
    // el cooldown cubre el resto del anti-bucle (espejo del modal de Expo).
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code39,
        BarcodeFormat.code128,
        BarcodeFormat.qrCode,
      ],
      autoZoom: true,
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _mostrarFeedback(EnvaseVeredicto veredicto) {
    setState(() => _feedback = veredicto);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(
      veredicto.ok ? _cooldownMs : _feedbackMs,
      () {
        if (!mounted) return;
        setState(() => _feedback = null);
        _cooldown = false;
      },
    );
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_busy || _cooldown) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final codigo = raw?.trim() ?? '';
    if (codigo.isEmpty) return;

    _busy = true;
    HapticService.light();
    try {
      final veredicto = await widget.onScanned(codigo);
      if (veredicto != null) {
        _cooldown = true;
        _mostrarFeedback(veredicto);
      }
    } catch (_) {
      _cooldown = true;
      _mostrarFeedback(const EnvaseVeredicto(
        ok: false,
        texto: 'No se pudo procesar la lectura. Intenta de nuevo.',
      ));
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  void _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF60A5FA);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) => _PermissionView(
              message: error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'El permiso de cámara fue denegado. Actívalo desde Ajustes '
                      'para poder escanear el código del envase.'
                  : 'No se pudo abrir la cámara (${error.errorCode.name}). '
                      'Verifica que ninguna otra app la esté usando.',
              onClose: widget.onClose,
            ),
          ),

          // Velo con ventana de escaneo recortada.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final frame = Rect.fromCenter(
                  center: Offset(
                    constraints.maxWidth / 2,
                    constraints.maxHeight / 2 - 30,
                  ),
                  width: 280,
                  height: 190,
                );
                return CustomPaint(
                  painter: _DimOverlayPainter(frame: frame),
                  child: _CornerFrame(frame: frame, color: azul),
                );
              },
            ),
          ),

          // Header: cerrar · título · linterna.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _RoundButton(
                      onPressed: widget.onClose,
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 26),
                    ),
                    Expanded(
                      child: Text(
                        'Escaneando envase',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _RoundButton(
                      onPressed: _toggleTorch,
                      backgroundColor:
                          _torch ? const Color(0xFFFBBF24) : null,
                      child: Icon(
                        _torch
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Indicador de verificación en curso.
          if (_busy)
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF60A5FA),
                  ),
                ),
              ),
            ),

          // Footer: veredicto sobreimpreso + ayuda + botón Listo.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _feedback == null
                          ? const SizedBox(width: double.infinity)
                          : Container(
                              key: ValueKey(
                                  '${_feedback!.ok}-${_feedback!.texto}'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _feedback!.ok
                                    ? const Color(0xCC10B981)
                                    : const Color(0xCCEF4444),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _feedback!.ok
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _feedback!.texto,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Apunta al código del envase a unos 15–25 cm. La cámara '
                      'sigue activa para el siguiente.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: const Color(0xFFD1D5DB), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: widget.onClose,
                      style: TextButton.styleFrom(
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text('Listo',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista de permiso denegado o error de cámara (equivale al modal de permiso
/// del modal de Expo).
class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_camera_outlined, size: 56, color: Color(0xFF60A5FA)),
          const SizedBox(height: 14),
          Text('Cámara no disponible',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: const Color(0xFFC7D2FE),
                  fontSize: 14,
                  height: 1.4)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onClose,
            child: Text('Cerrar',
                style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.onPressed, required this.child, this.backgroundColor});

  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: IconButton(padding: EdgeInsets.zero, onPressed: onPressed, icon: child),
    );
  }
}

/// Velo negro con hueco en la ventana de escaneo.
class _DimOverlayPainter extends CustomPainter {
  const _DimOverlayPainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final outer = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(frame.inflate(2), const Radius.circular(12)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DimOverlayPainter old) => frame != old.frame;
}

/// Esquinas del marco de escaneo.
class _CornerFrame extends StatelessWidget {
  const _CornerFrame({required this.frame, required this.color});

  final Rect frame;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const corner = 34.0;
    const width = 4.0;

    Widget cornerBox({
      required Alignment alignment,
      required BorderRadius radius,
    }) =>
        Align(
          alignment: alignment,
          child: Container(
            width: corner,
            height: corner,
            decoration: BoxDecoration(
              border: Border(
                top: alignment.y < 0
                    ? BorderSide(color: color, width: width)
                    : BorderSide.none,
                bottom: alignment.y > 0
                    ? BorderSide(color: color, width: width)
                    : BorderSide.none,
                left: alignment.x < 0
                    ? BorderSide(color: color, width: width)
                    : BorderSide.none,
                right: alignment.x > 0
                    ? BorderSide(color: color, width: width)
                    : BorderSide.none,
              ),
              borderRadius: radius,
            ),
          ),
        );

    return Stack(
      children: [
        Positioned(
          left: frame.left - 2,
          top: frame.top - 2,
          child: cornerBox(
            alignment: Alignment.topLeft,
            radius: const BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
        Positioned(
          right: frame.right,
          top: frame.top - 2,
          child: cornerBox(
            alignment: Alignment.topRight,
            radius: const BorderRadius.only(topRight: Radius.circular(12)),
          ),
        ),
        Positioned(
          left: frame.left - 2,
          bottom: frame.bottom,
          child: cornerBox(
            alignment: Alignment.bottomLeft,
            radius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
          ),
        ),
        Positioned(
          right: frame.right,
          bottom: frame.bottom,
          child: cornerBox(
            alignment: Alignment.bottomRight,
            radius: const BorderRadius.only(bottomRight: Radius.circular(12)),
          ),
        ),
      ],
    );
  }
}
