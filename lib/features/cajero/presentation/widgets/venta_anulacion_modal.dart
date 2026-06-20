import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/venta_model.dart';
import 'venta_constants.dart';


class VentaAnulacionModal extends StatefulWidget {
  final Venta venta;
  final bool isDark;
  final bool isSubmitting;
  final VoidCallback onClose;
  final void Function(String motivo, double monto) onEnviar;

  const VentaAnulacionModal({
    super.key,
    required this.venta,
    required this.isDark,
    required this.isSubmitting,
    required this.onClose,
    required this.onEnviar,
  });

  @override
  State<VentaAnulacionModal> createState() => _VentaAnulacionModalState();
}

class _VentaAnulacionModalState extends State<VentaAnulacionModal> {
  late TextEditingController _motivoController;
  late TextEditingController _montoController;
  String _montoAnulacion = '';

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController();
    _montoAnulacion = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '',
      decimalDigits: 0,
    ).format(widget.venta.total).trim();
    _montoController = TextEditingController(text: _montoAnulacion);
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  String get montoLimpio => _montoAnulacion.replaceAll(RegExp(r'[^\d]'), '');
  double get montoValor => double.tryParse(montoLimpio) ?? 0;
  String get motivo => _motivoController.text.trim();

  void _handleEnviar() {
    final monto = montoValor;
    final motivoStr = motivo;
    if (monto <= 0) {
      AppSnackBar.showError(context, 'Debes ingresar un monto mayor a 0');
      return;
    }
    if (monto > widget.venta.total) {
      AppSnackBar.showError(context, 'El monto no puede ser mayor al total de la venta');
      return;
    }
    if (motivoStr.isEmpty) {
      AppSnackBar.showError(context, 'Debes ingresar el motivo de la anulación');
      return;
    }
    widget.onEnviar(motivoStr, monto);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.isSubmitting ? null : widget.onClose,
          child: Container(color: Colors.black54),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
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
                      child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Solicitar Anulación',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completa el monto y el motivo para enviar la solicitud al administrador.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _infoText('Código', widget.venta.codigo.isNotEmpty ? widget.venta.codigo : '#${widget.venta.idVenta}'),
                          const SizedBox(height: 4),
                          _infoText('Cliente', widget.venta.clienteNombre),
                          const SizedBox(height: 4),
                          _infoText(
                            'Total referencia',
                            formatCurrency(widget.venta.total),
                            valueColor: primaryColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Monto solicitado *',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _montoController,
                      onChanged: (v) {
                        setState(() {
                          _montoAnulacion = formatMontoInput(v);
                        });
                      },
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Ingresa el monto',
                        filled: true,
                        fillColor: widget.isDark ? AppTheme.darkBgColor : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Motivo de la anulación *',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _motivoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe el motivo...',
                        filled: true,
                        fillColor: widget.isDark ? AppTheme.darkBgColor : Colors.white,
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: widget.isSubmitting ? null : widget.onClose,
                            child: Text('Cancelar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: widget.isSubmitting ? null : _handleEnviar,
                            child: widget.isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Enviar Solicitud',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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

  Widget _infoText(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? (widget.isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          ),
        ),
      ],
    );
  }
}
