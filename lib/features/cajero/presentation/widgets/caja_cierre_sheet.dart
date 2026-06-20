import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import 'caja_constants.dart';

class CajaCierreSheet extends StatelessWidget {
  final double totalNeto;
  final double apertura;
  final double efectivo;
  final double tarjeta;
  final double transferencia;
  final double devoluciones;
  final Future<void> Function(double montoCierre) onCerrar;

  const CajaCierreSheet({
    super.key,
    required this.totalNeto,
    required this.apertura,
    required this.efectivo,
    required this.tarjeta,
    required this.transferencia,
    required this.devoluciones,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cierre de Turno',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa el desglose de ingresos acumulados en el turno antes de proceder a cerrar la caja.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _breakdownRow(isDark, 'Monto Apertura (Base)', formatCurrency(apertura)),
          _breakdownRow(isDark, 'Efectivo en Caja', formatCurrency(efectivo)),
          _breakdownRow(isDark, 'Ventas con Tarjeta', formatCurrency(tarjeta)),
          _breakdownRow(isDark, 'Ventas con Transferencias', formatCurrency(transferencia)),
          if (devoluciones > 0)
            _breakdownRow(isDark, 'Devoluciones / Anulaciones', '- ${formatCurrency(devoluciones)}',
                isNegative: true),
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BALANCE TOTAL',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                formatCurrency(totalNeto),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.redAccent),
              ),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await onCerrar(totalNeto);
                navigator.pop();
              },
              child: Text(
                'Confirmar Cierre de Caja',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(bool isDark, String label, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isNegative
                  ? Colors.redAccent
                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
