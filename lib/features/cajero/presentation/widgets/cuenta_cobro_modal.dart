import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../domain/cuenta_model.dart';
import 'cuenta_constants.dart';


class CuentaCobroModal extends StatefulWidget {
  final Cuenta cuenta;
  final bool isDark;
  final Future<void> Function(String metodoPago, double propina, double cargoTarjeta) onCobrar;

  const CuentaCobroModal({
    super.key,
    required this.cuenta,
    required this.isDark,
    required this.onCobrar,
  });

  @override
  State<CuentaCobroModal> createState() => _CuentaCobroModalState();
}

class _CuentaCobroModalState extends State<CuentaCobroModal> {
  final _tipController = TextEditingController();
  String _metodoPago = 'efectivo';
  bool _applyTip = false;
  double _tipAmount = 0.0;
  double _cardFee = 0.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _tipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalConsumo = widget.cuenta.total;
    final double finalAmount = totalConsumo + _tipAmount + _cardFee;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: widget.isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
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
                  'Cobrar Cuenta Mesa ${widget.cuenta.roomName ?? ''}',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            _breakdownRow('Subtotal Consumo', formatCurrency(totalConsumo)),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Añadir Propina sugerida (10%)', style: GoogleFonts.inter(fontSize: 13)),
              value: _applyTip,
              onChanged: (val) {
                setState(() {
                  _applyTip = val ?? false;
                  if (_applyTip) {
                    _tipAmount = totalConsumo * 0.1;
                    _tipController.text = _tipAmount.toStringAsFixed(0);
                  } else {
                    _tipAmount = 0;
                    _tipController.clear();
                  }
                });
              },
            ),
            if (_applyTip) ...[
              TextFormField(
                controller: _tipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto Propina (\$)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) => setState(() => _tipAmount = double.tryParse(val) ?? 0.0),
              ),
              const SizedBox(height: 12),
            ],
            Text('Forma de Pago', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _metodoPago,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'transferencia', child: Text('Transferencia', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'prepago', child: Text('Prepago (Saldos)', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _metodoPago = val;
                    _cardFee = _metodoPago == 'tarjeta' ? totalConsumo * 0.02 : 0.0;
                  });
                }
              },
            ),
            if (_cardFee > 0) ...[
              const SizedBox(height: 8),
              _breakdownRow('Cargo tarjeta (2%)', formatCurrency(_cardFee), color: Colors.orange),
            ],
            const Divider(height: 24, thickness: 1),
            _breakdownRow('MONTO TOTAL A COBRAR', formatCurrency(finalAmount), isTotal: true, color: Colors.green),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : () async {
                  setState(() => _isSubmitting = true);
                  await widget.onCobrar(_metodoPago, _tipAmount, _cardFee);
                  if (context.mounted) Navigator.pop(context);
                },
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Completar Cobro', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          )),
          Text(value, style: GoogleFonts.inter(
            fontSize: isTotal ? 18 : 13,
            fontWeight: FontWeight.bold,
            color: color ?? (widget.isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          )),
        ],
      ),
    );
  }
}
