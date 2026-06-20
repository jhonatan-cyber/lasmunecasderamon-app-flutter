import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/hooks/set_state_provider.dart';
import '../../../../core/theme.dart';
import '../../../auth/data/auth_notifier.dart';
import '../../domain/gratificacion_model.dart';

class GratificacionNewModal extends ConsumerStatefulWidget {
  final List<GratificacionEmployee> employees;
  final VoidCallback onSuccess;

  const GratificacionNewModal({super.key, required this.employees, required this.onSuccess});

  @override
  ConsumerState<GratificacionNewModal> createState() => _GratificacionNewModalState();
}

class _GratificacionNewModalState extends ConsumerState<GratificacionNewModal> {
  String _employeeSearch = '';
  GratificacionEmployee? _selectedEmployee;
  final _montoController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _montoController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final cleanMonto = _montoController.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(cleanMonto) ?? 0.0;
    if (_selectedEmployee == null || amount <= 0) return;

    await ref.read(setStateProvider('gratificaciones').notifier).guard(() async {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post('/gratificaciones', data: {
        'usuario_id': _selectedEmployee!.id,
        'monto': amount,
        'descripcion': _descController.text.trim(),
      });

      if (response.data != null && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(response.data['pendingApproval'] == true
                ? 'Se envió al administrador por WhatsApp para aprobación'
                : 'Gratificación registrada correctamente'),
          ));
          Navigator.pop(context);
        }
        widget.onSuccess();
      } else {
        throw Exception(response.data?['message'] ?? 'No se pudo crear la gratificación');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmps = widget.employees.where((employee) {
      final term = _employeeSearch.trim().toLowerCase();
      if (term.isEmpty) return true;
      return '${employee.name} ${employee.lastName} ${employee.nick}'.toLowerCase().contains(term);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nueva Gratificación', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey[850], shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                  children: [
                    TextField(
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'Buscar empleado...', prefixIcon: Icon(Icons.search, color: AppTheme.darkTextSecondary)),
                      onChanged: (val) => setState(() => _employeeSearch = val),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(color: AppTheme.darkSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.builder(
                          itemCount: filteredEmps.length,
                          itemBuilder: (context, idx) {
                            final employee = filteredEmps[idx];
                            final isSelected = _selectedEmployee?.id == employee.id;
                            return Container(
                              decoration: BoxDecoration(color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent),
                              child: ListTile(
                                onTap: () => setState(() => _selectedEmployee = employee),
                                title: Text('${employee.name} ${employee.lastName}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                subtitle: Text('@${employee.nick.isNotEmpty ? employee.nick : 'sin-nick'} · ${employee.role}',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkTextSecondary)),
                                trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _montoController,
                      style: GoogleFonts.inter(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Monto', prefixIcon: Icon(Icons.payments_rounded, color: AppTheme.darkTextSecondary)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descController,
                      style: GoogleFonts.inter(color: Colors.white),
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Descripción (opcional)', prefixIcon: Icon(Icons.description_rounded, color: AppTheme.darkTextSecondary)),
                    ),
                    const SizedBox(height: 24),
                    Consumer(builder: (context, ref, _) {
                      final isSubmitting = ref.watch(setStateProvider('gratificaciones')).isSubmitting;
                      return ElevatedButton(
                        style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                        ),
                        onPressed: isSubmitting || _selectedEmployee == null || _montoController.text.isEmpty ? null : _handleSubmit,
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text('Enviar solicitud por WhatsApp', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
