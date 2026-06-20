import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../domain/cuenta_model.dart';


class CuentaActionSheet extends StatelessWidget {
  final Cuenta cuenta;
  final bool isDark;
  final VoidCallback onVerConsumos;
  final VoidCallback onAgregarProductos;
  final VoidCallback onDetenerTiempo;
  final VoidCallback onCobrar;
  final VoidCallback onAnular;
  final VoidCallback onCancel;

  const CuentaActionSheet({
    super.key,
    required this.cuenta,
    required this.isDark,
    required this.onVerConsumos,
    required this.onAgregarProductos,
    required this.onDetenerTiempo,
    required this.onCobrar,
    required this.onAnular,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mesa / Habitación: ${cuenta.roomName ?? 'Sin número'}',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Anfitriona: ${cuenta.anfitrionaNombre ?? 'Ninguna'} • Garzón: ${cuenta.garzonNombre ?? 'Ninguno'}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
            title: const Text('Ver Consumos y Detalles'),
            onTap: onVerConsumos,
          ),
          ListTile(
            leading: Icon(Icons.add_shopping_cart_rounded, color: Theme.of(context).colorScheme.primary),
            title: const Text('Agregar Productos'),
            onTap: onAgregarProductos,
          ),
          ListTile(
            leading: const Icon(Icons.timer_off_outlined, color: Colors.orange),
            title: const Text('Detener Tiempo / Parar Reloj'),
            onTap: onDetenerTiempo,
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale_rounded, color: Colors.green),
            title: const Text('Cobrar / Facturar Cuenta'),
            onTap: onCobrar,
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            title: const Text('Anular / Cancelar Cuenta'),
            onTap: onAnular,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onCancel,
              child: Text('Cancelar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
