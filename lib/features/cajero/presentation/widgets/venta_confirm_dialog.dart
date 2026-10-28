import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';

/// Diálogo de confirmación antes de finalizar una venta en proceso
/// (libera la habitación y detiene el temporizador).
void showFinalizarVentaConfirm(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor:
          isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      title: Text(
        'Finalizar Venta',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      content: Text(
        '¿Estás seguro de que deseas finalizar esta venta? Esto liberará la habitación y detendrá el temporizador.',
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cancelar',
            style: GoogleFonts.inter(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child: Text(
            'Finalizar',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
