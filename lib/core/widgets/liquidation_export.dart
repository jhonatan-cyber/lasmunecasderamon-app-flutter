import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../report_service.dart';
import '../theme.dart';
import 'app_snackbar.dart';
import 'currency_text.dart';

/// Exporta la liquidación de un usuario a PDF y la comparte con la hoja del
/// sistema — flujo espejo de `handleExportReport` de `PremiumLiquidationCard`
/// (app Expo). Devuelve `true` cuando el PDF se generó.
///
/// [totalAmount] es el «total a cobrar» que ya conoce la pantalla (en Expo es
/// `payoutTotal`, es decir `montoAnticipoMaximo` de `/users/me/stats`); si es
/// `null` se calcula con la regla de `calculateLiquidationTotal`.
Future<bool> exportLiquidationPdf(
  BuildContext context, {
  required List<LiquidationEvent> events,
  required String userLabel,
  double? totalAmount,
  String title = 'Reporte de Liquidación',
  String totalLabel = 'Total a cobrar',
}) async {
  final total = totalAmount ?? calculateLiquidationTotal(events);

  final path = await reportService.exportLiquidationReport(
    userLabel: userLabel,
    events: events,
    total: total,
    title: title,
    totalLabel: totalLabel,
  );

  if (!context.mounted) return false;

  if (path == null) {
    AppSnackBar.showError(context, 'No se pudo generar el reporte PDF');
    return false;
  }

  final shared = await reportService.shareReport(path, title);
  if (!context.mounted) return false;

  if (shared) {
    AppSnackBar.showSuccess(context, 'Reporte de liquidación generado');
  } else {
    // En escritorio o sin apps compatibles el archivo igual quedó guardado en
    // los documentos de la app.
    AppSnackBar.showWarning(context, 'Reporte guardado en el dispositivo');
  }
  return true;
}

/// Botón «Reportes» con estado de carga propio: genera el PDF de liquidación y
/// lo comparte. Reutilizado por la tarjeta de liquidación y por las pantallas
/// que ya muestran su propio total (home del garzón, administrativo del cajero).
class LiquidationExportButton extends StatefulWidget {
  const LiquidationExportButton({
    super.key,
    required this.events,
    required this.userLabel,
    this.totalAmount,
    this.title = 'Reporte de Liquidación',
    this.totalLabel = 'Total a cobrar',
    this.label = 'Reportes',
    this.backgroundColor,
    this.foregroundColor,
    this.dense = false,
    this.icon = Icons.description_rounded,
  });

  final List<LiquidationEvent> events;
  final String userLabel;
  final double? totalAmount;
  final String title;
  final String totalLabel;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool dense;
  final IconData icon;

  @override
  State<LiquidationExportButton> createState() =>
      _LiquidationExportButtonState();
}

class _LiquidationExportButtonState extends State<LiquidationExportButton> {
  bool _isExporting = false;

  Future<void> _export() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    await exportLiquidationPdf(
      context,
      events: widget.events,
      userLabel: widget.userLabel,
      totalAmount: widget.totalAmount,
      title: widget.title,
      totalLabel: widget.totalLabel,
    );

    if (mounted) setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final background =
        widget.backgroundColor ?? Theme.of(context).colorScheme.primary;
    final foreground = widget.foregroundColor ?? Colors.white;
    final iconSize = widget.dense ? 16.0 : 18.0;

    return ElevatedButton.icon(
      onPressed: _isExporting ? null : _export,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.65),
        disabledForegroundColor: foreground,
        elevation: 0,
        minimumSize: Size(0, widget.dense ? 36 : 48),
        padding: widget.dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.dense ? 20 : 12),
        ),
      ),
      icon: _isExporting
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            )
          : Icon(widget.icon, size: iconSize, color: foreground),
      label: Text(
        widget.label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: widget.dense ? 12 : 15,
        ),
      ),
    );
  }
}

/// Resumen del total a cobrar + botón «Reportes»: paridad con la fila de
/// acciones de `PremiumLiquidationCard` de Expo (mini-resumen a la izquierda,
/// exportación a PDF a la derecha).
class LiquidationExportCard extends StatelessWidget {
  const LiquidationExportCard({
    super.key,
    required this.events,
    required this.userLabel,
    this.totalAmount,
    this.title = 'Reporte de Liquidación',
    this.totalLabel = 'Total a cobrar',
  });

  final List<LiquidationEvent> events;
  final String userLabel;
  final double? totalAmount;
  final String title;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = totalAmount ?? calculateLiquidationTotal(events);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceColor
                  : AppTheme.lightSurfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppTheme.darkBorderColor
                    : AppTheme.lightBorderColor,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  totalLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(total),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LiquidationExportButton(
            events: events,
            userLabel: userLabel,
            totalAmount: totalAmount,
            title: title,
            totalLabel: totalLabel,
          ),
        ),
      ],
    );
  }
}
