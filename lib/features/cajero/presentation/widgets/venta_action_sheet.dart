import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../domain/venta_model.dart';
import 'venta_constants.dart';


class VentaActionSheet extends StatelessWidget {
  final Venta venta;
  final bool isDark;
  final VoidCallback onVerDetalles;
  final VoidCallback onFinalizar;
  final VoidCallback onSolicitarAnulacion;
  final VoidCallback onCancel;

  const VentaActionSheet({
    super.key,
    required this.venta,
    required this.isDark,
    required this.onVerDetalles,
    required this.onFinalizar,
    required this.onSolicitarAnulacion,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final puedeFinalizar = venta.estado == 2 || venta.estado == 3;
    final puedeAnular = venta.estado != 0 && venta.estado != 3;
    final color = statusColor(venta.estado);
    final label = statusLabel(venta.estado);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'Opciones de Venta',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Código: ${venta.codigo.isNotEmpty ? venta.codigo : '#${venta.idVenta}'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.visibility_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              'Ver Detalles',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            onTap: onVerDetalles,
          ),
          if (puedeFinalizar)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              title: Text(
                'Finalizar Venta',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              onTap: onFinalizar,
            ),
          if (puedeAnular)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              title: Text(
                'Solicitar Anulación',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
              onTap: onSolicitarAnulacion,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onCancel,
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
