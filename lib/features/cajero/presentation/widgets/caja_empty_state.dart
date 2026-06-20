import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';

class CajaEmptyState extends StatelessWidget {
  final VoidCallback? onAbrirCaja;

  const CajaEmptyState({super.key, this.onAbrirCaja});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.grey[850] : Colors.grey[100])!,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wallet_rounded,
              size: 36,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Caja Cerrada',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Inicia el turno para poder registrar las ventas, servicios, propinas y retiros del local.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: AppTheme.getPrimaryButtonStyle(context).copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.green),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white),
            label: Text(
              'Iniciar Turno',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: onAbrirCaja,
          ),
        ],
      ),
    );
  }
}
