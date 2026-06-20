import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import 'caja_constants.dart';

class CajaBreakdownSection extends StatelessWidget {
  final double efectivoEnCaja;
  final double totalTarjeta;
  final double totalTransferencia;
  final double apertura;
  final double totalServicios;
  final double totalVentas;
  final double totalAnticipo;
  final double totalDevoluciones;
  final double totalIva;
  final double totalPropina;
  final double totalComisiones;
  final double balanceTotal;

  const CajaBreakdownSection({
    super.key,
    required this.efectivoEnCaja,
    required this.totalTarjeta,
    required this.totalTransferencia,
    required this.apertura,
    required this.totalServicios,
    required this.totalVentas,
    required this.totalAnticipo,
    required this.totalDevoluciones,
    required this.totalIva,
    required this.totalPropina,
    required this.totalComisiones,
    required this.balanceTotal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: primary),
              const SizedBox(width: 8),
              Text(
                'Desglose del Turno',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildItem(isDark, 'Efectivo en Caja', efectivoEnCaja, color: Colors.green),
          _buildItem(isDark, 'Tarjetas', totalTarjeta),
          _buildItem(isDark, 'Transferencias', totalTransferencia),
          _buildItem(isDark, 'Monto Apertura', apertura),
          _buildItem(isDark, 'Servicios', totalServicios),
          _buildItem(isDark, 'Ventas', totalVentas),
          _buildItem(isDark, 'Anticipos Pagados', totalAnticipo, isNegative: true),
          _buildItem(isDark, 'Devoluciones', totalDevoluciones, isNegative: true),
          _buildItem(isDark, 'IVA', totalIva),
          _buildItem(isDark, 'Propinas', totalPropina),
          _buildItem(isDark, 'Comisiones', totalComisiones),
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL INGRESADO',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                formatCurrency(balanceTotal),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    bool isDark,
    String label,
    double value, {
    Color? color,
    bool isNegative = false,
  }) {
    if (value == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            isNegative ? '- ${formatCurrency(value)}' : formatCurrency(value),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ??
                  (isNegative
                      ? Colors.redAccent
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
