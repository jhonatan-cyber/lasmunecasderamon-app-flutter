import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Aviso de caja cerrada (espejo de `CajaStatusCheck` del dashboard): explica
/// el bloqueo y ofrece ir a abrir caja. Cada pantalla que escribe ventas o
/// movimientos de caja lo muestra cuando la caja está cerrada y deshabilita su
/// botón de envío (textos idénticos al `Alert` del dashboard).
///
/// [onReturnedFromCaja] se ejecuta al volver de la pantalla de Caja, para que
/// el estado se refresque sin recargar el resto de la pantalla.
class CajaClosedBanner extends StatelessWidget {
  const CajaClosedBanner({super.key, this.onReturnedFromCaja});

  final Future<void> Function()? onReturnedFromCaja;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No hay caja abierta.',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No se pueden realizar ventas sin una caja abierta.',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.push('/cajero/caja');
              if (!context.mounted) return;
              await onReturnedFromCaja?.call();
            },
            child: Text(
              'Abrir Caja',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
