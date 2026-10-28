import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';

/// Modal «Solicitar Anulación»: monto (≤ total de la venta) y motivo, que se
/// envían al administrador. El backdrop solo cierra si no hay una solicitud
/// en vuelo (`anulandoVenta`).
class VentaAnulacionModal extends StatelessWidget {
  const VentaAnulacionModal({
    super.key,
    required this.activeVenta,
    required this.anulandoVenta,
    required this.motivoController,
    required this.montoController,
    required this.onMontoChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  /// Venta de la que se pide la anulación (fila cruda del listado).
  final dynamic activeVenta;
  final bool anulandoVenta;
  final TextEditingController motivoController;
  final TextEditingController montoController;

  /// Aplica el formateo de miles al monto digitado.
  final ValueChanged<String> onMontoChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (!anulandoVenta) {
              onCancel();
            }
          },
          child: Container(color: Colors.black54),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceColor
                    : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Solicitar Anulación',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completa el monto y el motivo para enviar la solicitud al administrador.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildInfoText(
                            'Código',
                            activeVenta?['codigo'] ?? '-',
                            isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildInfoText(
                            'Cliente',
                            activeVenta?['cliente_nombre'] ?? 'Sin cliente',
                            isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildInfoText(
                            'Total referencia',
                            formatCurrency(
                              double.tryParse(
                                    activeVenta?['total']?.toString() ?? '0',
                                  ) ??
                                  0,
                            ),
                            isDark,
                            valueColor: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Monto solicitado *',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: montoController,
                      onChanged: onMontoChanged,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Ingresa el monto',
                        filled: true,
                        fillColor: isDark ? AppTheme.darkBgColor : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Motivo de la anulación *',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: motivoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe el motivo...',
                        filled: true,
                        fillColor: isDark ? AppTheme.darkBgColor : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: anulandoVenta ? null : onCancel,
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: anulandoVenta ? null : onSubmit,
                            child: anulandoVenta
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Enviar Solicitud',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoText(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color:
                valueColor ??
                (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          ),
        ),
      ],
    );
  }
}
