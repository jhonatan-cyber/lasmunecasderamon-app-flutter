import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme.dart';
import '../../data/auth_notifier.dart';

class RegistroAsistenciaModal extends ConsumerStatefulWidget {
  final VoidCallback onRegistered;

  const RegistroAsistenciaModal({super.key, required this.onRegistered});

  @override
  ConsumerState<RegistroAsistenciaModal> createState() => _RegistroAsistenciaModalState();

  static Future<void> show(BuildContext context, VoidCallback onRegistered) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegistroAsistenciaModal(onRegistered: onRegistered),
    );
  }
}

class _RegistroAsistenciaModalState extends ConsumerState<RegistroAsistenciaModal> {
  final TextEditingController _codigoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _registrarAsistencia(String code) async {
    if (code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un código de asistencia'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/attendance/register',
        data: {'qr_data': code.trim()},
      );

      final resData = response.data;
      if (resData != null && resData['success'] == true) {
        if (mounted) {
          final alreadyReg = resData['alreadyRegistered'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(alreadyReg
                  ? 'Ya tienes asistencia registrada hoy'
                  : '¡Asistencia registrada correctamente!'),
              backgroundColor: alreadyReg ? Colors.orangeAccent : AppTheme.successColor,
            ),
          );
          Navigator.of(context).pop(); 
          widget.onRegistered();
        }
      } else {
        throw Exception(resData?['message'] ?? 'Código inválido');
      }
    } catch (e) {
      if (mounted) {
        String errMsg = 'Error al registrar asistencia';
        if (e is DioException && e.response?.data != null) {
          errMsg = e.response?.data['message'] ?? errMsg;
        } else if (e is Exception) {
          errMsg = e.toString().replaceAll('Exception:', '').trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openCameraScanner() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: double.infinity,
              height: 420,
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) async {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final qrData = barcodes.first.rawValue;
                        if (qrData != null) {
                          Navigator.of(context).pop(); 
                          _registrarAsistencia(qrData); 
                        }
                      }
                    },
                  ),
                  
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    
    final accentTheme = ref.watch(accentColorProvider);
    final accentColor = accentTheme.color;
    
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.gray500Color;
    final borderColor = isDark ? AppTheme.darkSurfaceAltColor : Colors.grey.shade200;

    final authState = ref.watch(authProvider);
    final user = authState.user;

    final initialNameChar = user?.nombre.isNotEmpty == true ? user!.nombre[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.calendar_today_rounded, color: accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar Asistencia',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ingresa tu código o escanea el QR para registrar tu asistencia',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initialNameChar,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user?.nombre ?? 'Usuario',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (user?.role ?? 'ANFITRIONA').toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          
          Text(
            'Código de Asistencia',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codigoController,
            decoration: InputDecoration(
              hintText: 'Ingresa el código ej: ATT-1234',
              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 13),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              prefixIcon: Icon(Icons.vpn_key_outlined, color: accentColor, size: 20),
            ),
            style: TextStyle(color: textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          
          
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () => _registrarAsistencia(_codigoController.text),
              icon: _isLoading
                  ? const SizedBox()
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Confirmar Código',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 16),

          
          Row(
            children: [
              Expanded(child: Divider(color: borderColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'O',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
              ),
              Expanded(child: Divider(color: borderColor)),
            ],
          ),
          const SizedBox(height: 16),

          
          InkWell(
            onTap: _openCameraScanner,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escanear QR',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Apunta al código QR del cajero',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textSecondary, size: 24),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRegistered();
              },
              child: Text(
                'Continuar sin asistencia',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
