import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';

/// Bottom sheet «Opciones de Venta» (tap en una tarjeta): ver detalles,
/// finalizar (estado 2/3) o solicitar anulación (estado != 0 y != 3).
void showVentaActionSheet(
  BuildContext context, {
  required dynamic venta,
  required VoidCallback onVerDetalles,
  required VoidCallback onFinalizar,
  required VoidCallback onAnular,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final int estado = int.tryParse(venta['estado']?.toString() ?? '1') ?? 1;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkSurfaceColor
              : AppTheme.lightSurfaceColor,
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
              child: Text(
                'Opciones de Venta',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Código: ${venta['codigo'] ?? venta['id_venta'] ?? ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
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
              onTap: () {
                Navigator.pop(ctx);
                onVerDetalles();
              },
            ),
            if (estado == 2 || estado == 3)
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
                onTap: () {
                  Navigator.pop(ctx);
                  onFinalizar();
                },
              ),
            if (estado != 0 && estado != 3)
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
                onTap: () {
                  Navigator.pop(ctx);
                  onAnular();
                },
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
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
