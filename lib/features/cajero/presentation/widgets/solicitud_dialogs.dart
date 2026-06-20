import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';


Future<bool?> showAprobarAnticipoDialog(
  BuildContext context, {
  required double monto,
  required String solicitadoPor,
  bool requiereAprobacionAdmin = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        title: Text(
          requiereAprobacionAdmin
              ? 'Aprobar y Pagar Anticipo'
              : 'Entregar Efectivo',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Confirmas que has entregado el efectivo de ${formatCurrency(monto)} a $solicitadoPor?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Confirmar Pago',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}


Future<bool?> showRechazarDialog(
  BuildContext context, {
  required String tipoItem,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final nameStr = tipoItem == 'solicitud' ? 'servicio' : 'pedido';

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        title: Text(
          'Rechazar Solicitud',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Seguro que deseas rechazar este $nameStr?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Rechazar',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}
