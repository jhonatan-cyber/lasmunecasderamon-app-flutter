import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/hooks/set_state_provider.dart';
import '../../../../core/theme.dart';
import '../../domain/client_model.dart';
import 'client_payment_method_selector.dart';

class ClientChargeDialog extends StatefulWidget {
  final Client client;
  final Future<void> Function(
    Client client,
    double amount,
    String metodoPago,
    String primaryMethod,
    double primaryAmount,
    String secondaryMethod,
    double secondaryAmount,
  ) onCharge;

  const ClientChargeDialog({
    super.key,
    required this.client,
    required this.onCharge,
  });

  @override
  State<ClientChargeDialog> createState() => _ClientChargeDialogState();
}

class _ClientChargeDialogState extends State<ClientChargeDialog> {
  final _amountCtrl = TextEditingController();
  final _primaryAmountCtrl = TextEditingController();
  final _secondaryAmountCtrl = TextEditingController();
  String _loadMetodoPago = 'efectivo';
  String _primaryMethod = 'efectivo';
  String _secondaryMethod = 'transferencia';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _primaryAmountCtrl.dispose();
    _secondaryAmountCtrl.dispose();
    super.dispose();
  }

  String _formatNumberString(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    final numValue = int.parse(clean);
    final formatter = NumberFormat.decimalPattern('es_CL');
    return formatter.format(numValue);
  }

  void _onAmountChanged(String val) {
    final formatted = _formatNumberString(val);
    if (formatted != val) {
      _amountCtrl.text = formatted;
      _amountCtrl.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
    }
  }

  void _onPrimaryAmountChanged(String val) {
    final formatted = _formatNumberString(val);
    if (formatted != val) {
      _primaryAmountCtrl.text = formatted;
      _primaryAmountCtrl.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
    }
    _syncSecondaryAmount();
  }

  void _onSecondaryAmountChanged(String val) {
    final formatted = _formatNumberString(val);
    if (formatted != val) {
      _secondaryAmountCtrl.text = formatted;
      _secondaryAmountCtrl.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
    }
    _syncPrimaryAmount();
  }

  void _syncSecondaryAmount() {
    final totalStr = _amountCtrl.text.replaceAll('.', '');
    final primaryStr = _primaryAmountCtrl.text.replaceAll('.', '');
    final total = int.tryParse(totalStr) ?? 0;
    final primary = int.tryParse(primaryStr) ?? 0;
    if (total >= primary) {
      final secondary = total - primary;
      final formatted = _formatNumberString(secondary.toString());
      _secondaryAmountCtrl.text = formatted;
    } else {
      _secondaryAmountCtrl.text = '0';
    }
  }

  void _syncPrimaryAmount() {
    final totalStr = _amountCtrl.text.replaceAll('.', '');
    final secondaryStr = _secondaryAmountCtrl.text.replaceAll('.', '');
    final total = int.tryParse(totalStr) ?? 0;
    final secondary = int.tryParse(secondaryStr) ?? 0;
    if (total >= secondary) {
      final primary = total - secondary;
      final formatted = _formatNumberString(primary.toString());
      _primaryAmountCtrl.text = formatted;
    } else {
      _primaryAmountCtrl.text = '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cargar Saldo', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(
                          widget.client.fullName,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('MONTO A CARGAR', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  prefixText: r'$ ',
                ),
                onChanged: (val) {
                  _onAmountChanged(val);
                  if (_loadMetodoPago == 'mixto') {
                    _primaryAmountCtrl.clear();
                    _secondaryAmountCtrl.clear();
                  }
                },
              ),
              const SizedBox(height: 20),
              ClientPaymentMethodSelector(
                selected: _loadMetodoPago,
                onSelect: (val) => setState(() => _loadMetodoPago = val),
                showMixto: true,
              ),
              if (_loadMetodoPago == 'mixto') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distribución de Pago', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ClientPaymentMethodSelector(
                              selected: _primaryMethod,
                              onSelect: (val) => setState(() => _primaryMethod = val),
                              showMixto: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _primaryAmountCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(hintText: r'$ 0', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                              onChanged: (val) => setState(() => _onPrimaryAmountChanged(val)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ClientPaymentMethodSelector(
                              selected: _secondaryMethod,
                              onSelect: (val) => setState(() => _secondaryMethod = val),
                              showMixto: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _secondaryAmountCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(hintText: r'$ 0', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                              onChanged: (val) => setState(() => _onSecondaryAmountChanged(val)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Consumer(builder: (context, ref, _) {
                  final isSubmitting = ref.watch(setStateProvider('clientes_submit')).isSubmitting;
                  return ElevatedButton(
                    style: AppTheme.getPrimaryButtonStyle(context),
                    onPressed: isSubmitting
                        ? null
                        : () => widget.onCharge(
                              widget.client,
                              double.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0.0,
                              _loadMetodoPago,
                              _primaryMethod,
                              double.tryParse(_primaryAmountCtrl.text.replaceAll('.', '')) ?? 0.0,
                              _secondaryMethod,
                              double.tryParse(_secondaryAmountCtrl.text.replaceAll('.', '')) ?? 0.0,
                            ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('CONFIRMAR CARGA'),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
