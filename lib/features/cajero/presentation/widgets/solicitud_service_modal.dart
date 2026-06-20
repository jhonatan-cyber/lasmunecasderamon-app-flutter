import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/hooks/set_state_provider.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../../auth/data/auth_notifier.dart';
import '../../data/solicitud_item.dart';

class ServiceModalWidget extends ConsumerStatefulWidget {
  final SolicitudItem item;
  final List<dynamic> allHostesses;
  final VoidCallback onSuccess;

  const ServiceModalWidget({
    super.key,
    required this.item,
    required this.allHostesses,
    required this.onSuccess,
  });

  @override
  ConsumerState<ServiceModalWidget> createState() =>
      _ServiceModalWidgetState();
}

class _ServiceModalWidgetState extends ConsumerState<ServiceModalWidget> {
  String _selectedAnfitriona = '';
  double _comisionAnfitriona = 0;

  @override
  void initState() {
    super.initState();
    
    if (widget.item.anfitrionasIds != null &&
        widget.item.anfitrionasIds!.isNotEmpty) {
      _selectedAnfitriona = widget.item.anfitrionasIds!.first.toString();
    }
    _comisionAnfitriona = widget.item.comisionAnfitriona ?? 0;
  }

  Future<void> _handleApproveService() async {
    await ref.read(setStateProvider('service_modal').notifier).guard(() async {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.patch(
        '/solicitudes-servicios/${widget.item.id}',
        data: {
          'estado': 1,
          'anfitriona_id': _selectedAnfitriona.isNotEmpty
              ? int.tryParse(_selectedAnfitriona)
              : null,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        AppSnackBar.showSuccess(context, 'Servicio aprobado correctamente.');
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        if (!mounted) return;
        AppSnackBar.showError(
          context,
          response.data?['message'] ?? 'Error al aprobar servicio',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSubmitting = ref.watch(setStateProvider('service_modal')).isSubmitting;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorderColor
              : AppTheme.lightBorderColor,
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aprobar Servicio',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),

            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceColor
                    : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : AppTheme.lightBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hab: ${widget.item.roomName}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(isDark, 'Solicitado por',
                      widget.item.solicitadoPor),
                  _infoRow(
                    isDark,
                    'Total',
                    formatCurrency(widget.item.monto),
                  ),
                  _infoRow(
                    isDark,
                    'Tiempo',
                    '${widget.item.tiempo ?? 0} min',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            
            Text(
              'ASIGNAR ANFITRIONA',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedAnfitriona.isNotEmpty
                  ? _selectedAnfitriona
                  : null,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Seleccionar anfitriona',
              ),
              items: widget.allHostesses.map((h) {
                final id = h['id']?.toString() ?? '';
                final name = h['nombre']?.toString() ?? h['name']?.toString() ?? '';
                return DropdownMenuItem(
                  value: id,
                  child: Text(name, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedAnfitriona = val);
                }
              },
            ),
            const SizedBox(height: 8),

            
            if (_comisionAnfitriona > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comisión Anfitriona: ${formatCurrency(_comisionAnfitriona)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _handleApproveService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Aprobar Servicio',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
