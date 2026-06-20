import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../domain/caja_data.dart';
import 'caja_constants.dart';

class CajaStatusCard extends StatelessWidget {
  final bool cajaAbierta;
  final CajaInfo? cajaInfo;
  final VoidCallback? onAbrirCaja;
  final VoidCallback? onRetiro;
  final VoidCallback? onCerrar;

  const CajaStatusCard({
    super.key,
    required this.cajaAbierta,
    this.cajaInfo,
    this.onAbrirCaja,
    this.onRetiro,
    this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              
              _statusPill(context, isDark),
              
              _actionButtons(isDark),
            ],
          ),
          if (cajaAbierta && cajaInfo != null) ...[
            const Divider(height: 24, thickness: 1),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Apertura: ${formatDateTime(cajaInfo!.fechaApertura)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cajaAbierta
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cajaAbierta ? Colors.green : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            cajaAbierta ? 'Caja Abierta' : 'Caja Cerrada',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cajaAbierta ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(bool isDark) {
    if (cajaAbierta) {
      return Row(
        children: [
          _miniButton(
            label: 'Retiro',
            icon: Icons.arrow_downward_rounded,
            bgColor: Colors.orange.withValues(alpha: 0.15),
            fgColor: Colors.orange,
            onPressed: onRetiro,
          ),
          const SizedBox(width: 8),
          _miniButton(
            label: 'Cerrar',
            icon: Icons.lock_rounded,
            bgColor: Colors.redAccent.withValues(alpha: 0.15),
            fgColor: Colors.redAccent,
            onPressed: onCerrar,
          ),
        ],
      );
    }

    return _miniButton(
      label: 'Abrir Caja',
      icon: Icons.play_arrow_rounded,
      bgColor: Colors.green.withValues(alpha: 0.15),
      fgColor: Colors.green,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      iconSize: 16,
      fontSize: 13,
      onPressed: onAbrirCaja,
    );
  }

  Widget _miniButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
    double iconSize = 14,
    double fontSize = 12,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      icon: Icon(icon, size: iconSize),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
    );
  }
}
