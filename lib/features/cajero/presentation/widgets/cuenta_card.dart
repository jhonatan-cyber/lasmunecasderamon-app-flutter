import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../domain/cuenta_model.dart';
import 'cuenta_constants.dart';


class CuentaCard extends StatelessWidget {
  final Cuenta cuenta;
  final bool isDark;
  final String elapsedTime;
  final VoidCallback onTap;

  const CuentaCard({
    super.key,
    required this.cuenta,
    required this.isDark,
    required this.elapsedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Mesa / Hab: ${cuenta.roomName ?? 'Sin Nro'}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 10, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                elapsedTime,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Anfitriona: ${cuenta.anfitrionaNombre ?? 'Ninguna'}',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    Text(
                      'Garzón: ${cuenta.garzonNombre ?? 'Ninguno'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(cuenta.total),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
