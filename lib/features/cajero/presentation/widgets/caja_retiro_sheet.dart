import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import 'caja_constants.dart';

class CajaRetiroSheet extends StatefulWidget {
  final Future<void> Function(double monto, String motivo) onRetirar;
  final double efectivoDisponible;

  const CajaRetiroSheet({
    super.key,
    required this.onRetirar,
    required this.efectivoDisponible,
  });

  @override
  State<CajaRetiroSheet> createState() => _CajaRetiroSheetState();
}

class _CajaRetiroSheetState extends State<CajaRetiroSheet> {
  final _montoController = TextEditingController();
  final _motivoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _montoController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Retirar Efectivo',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Retirar dinero en efectivo de la caja activa. Quedará registrado en el historial.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Efectivo disponible en caja: ${formatCurrency(widget.efectivoDisponible)}',
                      style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto a Retirar (\$)',
                  hintText: 'Ej: 20000',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Ingresa un monto';
                  final n = double.tryParse(val);
                  if (n == null || n <= 0) return 'Ingresa un monto válido';
                  if (n > widget.efectivoDisponible) return 'Monto supera el efectivo en caja';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivoController,
                decoration: const InputDecoration(
                  labelText: 'Motivo del Retiro',
                  hintText: 'Ej: Entrega a administración',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa el motivo del retiro';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.orange),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState?.validate() == true) {
                      final val = double.parse(_montoController.text);
                      final navigator = Navigator.of(context);
                      await widget.onRetirar(val, _motivoController.text);
                      navigator.pop();
                    }
                  },
                  child: Text(
                    'Confirmar Retiro',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
