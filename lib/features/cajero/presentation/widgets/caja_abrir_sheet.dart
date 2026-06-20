import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';

class CajaAbrirSheet extends StatefulWidget {
  final Future<void> Function(double monto) onAbrirCaja;

  const CajaAbrirSheet({super.key, required this.onAbrirCaja});

  @override
  State<CajaAbrirSheet> createState() => _CajaAbrirSheetState();
}

class _CajaAbrirSheetState extends State<CajaAbrirSheet> {
  final _montoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _montoController.dispose();
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
                    'Apertura de Turno',
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
                'Ingresa el monto base de efectivo para iniciar la caja de este turno.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto de Apertura (\$)',
                  hintText: 'Ej: 100000',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Ingresa un monto';
                  final n = double.tryParse(val);
                  if (n == null || n < 0) return 'Ingresa un número válido';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.green),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState?.validate() == true) {
                      final val = double.parse(_montoController.text);
                      final navigator = Navigator.of(context);
                      await widget.onAbrirCaja(val);
                      navigator.pop();
                    }
                  },
                  child: Text(
                    'Iniciar Turno',
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
