import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';


class CuentaAnulacionModal extends StatefulWidget {
  final bool isDark;
  final Future<void> Function(String motivo) onAnular;

  const CuentaAnulacionModal({
    super.key,
    required this.isDark,
    required this.onAnular,
  });

  @override
  State<CuentaAnulacionModal> createState() => _CuentaAnulacionModalState();
}

class _CuentaAnulacionModalState extends State<CuentaAnulacionModal> {
  final _motivoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _isSubmitting = true);
    await widget.onAnular(_motivoController.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      title: Text('Anulación de Cuenta', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Estás seguro de que deseas anular esta cuenta por completo? Esta acción liberará la mesa.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo de Anulación',
                hintText: 'Ej: Cliente se retira / Error de registro',
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'El motivo es requerido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('Cancelar', style: GoogleFonts.inter(
            color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          )),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Confirmar Anulación', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
