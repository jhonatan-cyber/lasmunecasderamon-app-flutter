import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';

class GratificacionSummaryCard extends StatelessWidget {
  final double pendiente;
  final double porPagar;
  final double pagado;

  const GratificacionSummaryCard({
    super.key,
    required this.pendiente,
    required this.porPagar,
    required this.pagado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL PENDIENTE DE APROBACIÓN',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.darkTextSecondary, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Text(formatCurrency(pendiente), style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.orange)),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Por pagar: ${formatCurrency(porPagar)}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold)),
              Container(width: 1, height: 12, color: Colors.white10),
              Text('Pagado: ${formatCurrency(pagado)}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
