import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../features/auth/data/auth_notifier.dart';

const double _kZoomNormal = 0.0;
const double _kZoomMacro = 0.15;
















class QRScannerModal<T> extends ConsumerStatefulWidget {
  const QRScannerModal({
    super.key,
    required this.onScanned,
  });

  
  
  final Future<T> Function(String data) onScanned;

  
  static Future<T?> show<T>(
    BuildContext context, {
    required Future<T> Function(String data) onScanned,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, a1, a2) => QRScannerModal<T>(onScanned: onScanned),
        transitionsBuilder: (ctx, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  ConsumerState<QRScannerModal<T>> createState() => _QRScannerModalState<T>();
}

class _QRScannerModalState<T> extends ConsumerState<QRScannerModal<T>>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 500,
    autoZoom: true,
  );

  bool _scanning = false;
  bool _cameraActive = false;
  bool _torch = false;
  double _zoom = _kZoomNormal;
  String? _codigo;
  Timer? _cameraTimer;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    
    _cameraTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _cameraActive = true);
    });

    _fetchCodigo();
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _pulseCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchCodigo() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/codigo/actual');
      if (res.data['success'] == true && mounted) {
        setState(() => _codigo = res.data['codigo']?.toString());
      }
    } catch (_) {}
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    setState(() => _scanning = true);
    final data = raw.trim();

    widget.onScanned(data).then((result) {
      if (mounted) Navigator.of(context).pop(result);
    }).catchError((Object error) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
      setState(() => _scanning = false);
    });
  }

  void _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _torch = !_torch);
    } catch (_) {}
  }

  void _toggleZoom() {
    setState(() {
      _zoom = _zoom == _kZoomNormal ? _kZoomMacro : _kZoomNormal;
    });
    _controller.setZoomScale(_zoom);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            
            if (_cameraActive)
              MobileScanner(
                controller: _controller,
                onDetect: _handleBarcode,
                scanWindow: _scanWindow(context),
                overlayBuilder: (ctx, constraints) {
                  final window = _scanWindow(ctx);
                  return Stack(
                    children: [
                      
                      ScanWindowOverlay(
                        controller: _controller,
                        scanWindow: window,
                        color: Colors.black.withValues(alpha: 0.65),
                        borderWidth: 0,
                      ),
                      
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (ctx, _) => CustomPaint(
                          painter: _CornerFramePainter(
                            scanWindow: window,
                            color: accentColor,
                            scale: _pulse.value,
                          ),
                          size: constraints.biggest,
                        ),
                      ),
                    ],
                  );
                },
              ),

            
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    
                    _HeaderButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    ),
                    Text(
                      'Escanear QR',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeaderButton(
                          onPressed: _toggleZoom,
                          backgroundColor:
                              _zoom > 0 ? const Color(0xFF34D399) : null,
                          child: Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeaderButton(
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
                  ],
                ),
              ),
            ),

            
            Positioned(
              bottom: 32,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  if (_codigo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Código: ',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _codigo!,
                            style: GoogleFonts.inter(
                              color: accentColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _zoom > 0
                          ? 'Modo macro activo. Aleja el QR unos 10–15 cm.'
                          : 'Apunta al código QR a unos 15–25 cm de distancia.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Cerrar',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Rect _scanWindow(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWidth = size.width * 0.75;
    final scanHeight = size.height * 0.45;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 20),
      width: scanWidth,
      height: scanHeight,
    );
  }
}



class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.onPressed,
    this.backgroundColor,
    required this.child,
  });

  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: child,
        padding: EdgeInsets.zero,
      ),
    );
  }
}



class _CornerFramePainter extends CustomPainter {
  _CornerFramePainter({
    required this.scanWindow,
    required this.color,
    this.scale = 1.0,
  });

  final Rect scanWindow;
  final Color color;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 40.0;
    final inset = 2.0;

    
    canvas.drawLine(
      Offset(scanWindow.left - inset, scanWindow.top - inset),
      Offset(scanWindow.left - inset + cornerLen * scale, scanWindow.top - inset),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.left - inset, scanWindow.top - inset),
      Offset(scanWindow.left - inset, scanWindow.top - inset + cornerLen * scale),
      paint,
    );

    
    canvas.drawLine(
      Offset(scanWindow.right + inset, scanWindow.top - inset),
      Offset(scanWindow.right + inset - cornerLen * scale, scanWindow.top - inset),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.right + inset, scanWindow.top - inset),
      Offset(scanWindow.right + inset, scanWindow.top - inset + cornerLen * scale),
      paint,
    );

    
    canvas.drawLine(
      Offset(scanWindow.right + inset, scanWindow.bottom + inset),
      Offset(scanWindow.right + inset - cornerLen * scale, scanWindow.bottom + inset),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.right + inset, scanWindow.bottom + inset),
      Offset(scanWindow.right + inset, scanWindow.bottom + inset - cornerLen * scale),
      paint,
    );

    
    canvas.drawLine(
      Offset(scanWindow.left - inset, scanWindow.bottom + inset),
      Offset(scanWindow.left - inset + cornerLen * scale, scanWindow.bottom + inset),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.left - inset, scanWindow.bottom + inset),
      Offset(scanWindow.left - inset, scanWindow.bottom + inset - cornerLen * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerFramePainter old) =>
      scanWindow != old.scanWindow ||
      color != old.color ||
      scale != old.scale;
}
