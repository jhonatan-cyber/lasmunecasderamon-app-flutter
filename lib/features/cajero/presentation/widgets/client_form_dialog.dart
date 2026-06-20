import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/hooks/set_state_provider.dart';
import '../../../../core/theme.dart';
import '../../domain/client_model.dart';

class ClientFormDialog extends StatefulWidget {
  final Client? client;
  final Future<void> Function(Client? editingClient, String name, String lastName, String run, String phone) onSave;

  const ClientFormDialog({super.key, this.client, required this.onSave});

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _runCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.client?.name ?? '');
    _lastNameCtrl = TextEditingController(text: widget.client?.lastName ?? '');
    _runCtrl = TextEditingController(text: widget.client?.run ?? '');
    _phoneCtrl = TextEditingController(text: widget.client?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _runCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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
                      widget.client != null ? 'Editar Cliente' : 'Nuevo Cliente',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (val) => (val == null || val.isEmpty) ? 'El nombre es obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: const InputDecoration(labelText: 'Apellido *'),
                  validator: (val) => (val == null || val.isEmpty) ? 'El apellido es obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _runCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: const InputDecoration(labelText: 'RUN / RUT'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Consumer(builder: (context, ref, _) {
                    final isSubmitting = ref.watch(setStateProvider('clientes_submit')).isSubmitting;
                    return ElevatedButton(
                      style: AppTheme.getPrimaryButtonStyle(context),
                      onPressed: isSubmitting
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                widget.onSave(
                                  widget.client,
                                  _nameCtrl.text.trim(),
                                  _lastNameCtrl.text.trim(),
                                  _runCtrl.text.trim(),
                                  _phoneCtrl.text.trim(),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(widget.client != null ? 'ACTUALIZAR' : 'CREAR CLIENTE'),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
