import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dio/dio.dart';
import '../../../auth/data/auth_notifier.dart';

class AttendanceCodeDisplay extends ConsumerStatefulWidget {
  const AttendanceCodeDisplay({super.key});

  @override
  ConsumerState<AttendanceCodeDisplay> createState() => _AttendanceCodeDisplayState();
}

class _AttendanceCodeDisplayState extends ConsumerState<AttendanceCodeDisplay> {
  String _codigo = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchCodigo());
  }

  Future<void> _fetchCodigo() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null || !user.isCajeroOrAdmin) return;

    setState(() {
      _loading = true;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get(
        '/codigo/actual',
        options: Options(
          headers: {'x-user-role': user.role},
        ),
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        setState(() {
          _codigo = data['codigo']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('[AttendanceCodeDisplay] Error al cargar código: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showQRDialog(BuildContext context, String code) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgModal = isDark ? Colors.black.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.98);
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final accentColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: bgModal,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        icon: Icon(Icons.close, size: 28, color: textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.qr_code_rounded,
                                  size: 32,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Código de Asistencia',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pide a tus compañeros que escaneen este código para registrar su asistencia',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: 220,
                                height: 220,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: _loading
                                    ? Center(child: CircularProgressIndicator(color: accentColor))
                                    : code.isNotEmpty
                                        ? QrImageView(
                                            data: code,
                                            version: QrVersions.auto,
                                            size: 200.0,
                                            eyeStyle: const QrEyeStyle(
                                              eyeShape: QrEyeShape.square,
                                              color: Colors.black,
                                            ),
                                            dataModuleStyle: const QrDataModuleStyle(
                                              dataModuleShape: QrDataModuleShape.square,
                                              color: Colors.black,
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              'Sin código activo',
                                              style: GoogleFonts.inter(color: textSecondary),
                                            ),
                                          ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'CÓDIGO: ',
                                      style: GoogleFonts.inter(
                                        color: textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      code.isNotEmpty ? code : '----',
                                      style: GoogleFonts.inter(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.refresh, size: 20, color: accentColor),
                                    onPressed: () async {
                                      setDialogState(() {
                                        _loading = true;
                                      });
                                      await _fetchCodigo();
                                      setDialogState(() {
                                        _loading = false;
                                      });
                                    },
                                  ),
                                  Text(
                                    'Se actualiza automáticamente cada mañana',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null || !user.isCajeroOrAdmin) {
      return const SizedBox.shrink();
    }

    final accentColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () async {
        final ctx = context;
        await _fetchCodigo();
        if (!ctx.mounted) return;
        _showQRDialog(ctx, _codigo);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Código: ',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            _loading
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _codigo.isNotEmpty ? _codigo : '****',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
