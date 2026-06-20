import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import 'caja_constants.dart';

class CajaMetricsGrid extends StatelessWidget {
  final double balanceTotal;
  final double totalVentas;
  final double totalServicios;
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalTransferencia;
  final int cantidadVentas;
  final int cantidadServicios;

  const CajaMetricsGrid({
    super.key,
    required this.balanceTotal,
    required this.totalVentas,
    required this.totalServicios,
    required this.totalEfectivo,
    required this.totalTarjeta,
    required this.totalTransferencia,
    required this.cantidadVentas,
    required this.cantidadServicios,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      children: [
        _metricCard(isDark, 'Balance Total', balanceTotal, Icons.account_balance_wallet_rounded, primary),
        _metricCard(isDark, 'Total Ventas', totalVentas, Icons.shopping_cart_rounded, Colors.green,
            subtitle: '$cantidadVentas ventas'),
        _metricCard(isDark, 'Total Servicios', totalServicios, Icons.hotel_rounded, Colors.blueAccent,
            subtitle: '$cantidadServicios servicios'),
        _metricCard(isDark, 'Efectivo', totalEfectivo, Icons.attach_money_rounded, Colors.orange),
        _metricCard(isDark, 'Tarjetas', totalTarjeta, Icons.credit_card_rounded, Colors.purple),
        _metricCard(isDark, 'Transferencias', totalTransferencia, Icons.swap_horizontal_circle_rounded, Colors.pink),
      ],
    );
  }

  Widget _metricCard(
    bool isDark,
    String label,
    double value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatCurrency(value),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
