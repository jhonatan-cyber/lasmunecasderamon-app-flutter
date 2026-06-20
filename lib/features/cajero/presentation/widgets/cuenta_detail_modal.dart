import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../domain/cuenta_model.dart';
import 'cuenta_constants.dart';


class CuentaDetailModal extends StatelessWidget {
  final CuentaDetail cuentaDetail;
  final bool isDark;
  final VoidCallback onClose;

  const CuentaDetailModal({
    super.key,
    required this.cuentaDetail,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = cuentaDetail;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consumo Mesa ${c.roomName ?? ''}',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow(isDark, 'Apertura', formatElapsedTime(c.fechaApertura)),
          _detailRow(isDark, 'Garzón', c.garzonNombre ?? 'Ninguno'),
          _detailRow(isDark, 'Anfitriona', c.anfitrionaNombre ?? 'Ninguna'),
          _detailRow(isDark, 'Cliente', c.clienteNombre ?? 'Cliente General'),
          const Divider(height: 32, thickness: 1),
          Text('Detalle Consumos', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (c.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No se han registrado consumos en esta comanda.',
                style: GoogleFonts.inter(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            )
          else
            ...c.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productoNombre, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        Text(
                          '${item.cantidad} x ${formatCurrency(item.precio)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrency(item.precio * item.cantidad),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
          const Divider(height: 32, thickness: 1),
          _priceRow('Subtotal', formatCurrency(c.subtotal)),
          if (c.descuento > 0)
            _priceRow('Descuento', '- ${formatCurrency(c.descuento)}', color: Colors.redAccent),
          _priceRow('Consumo Estimado', formatCurrency(c.total), isTotal: true, color: Colors.green),
        ],
      ),
    );
  }

  Widget _detailRow(bool isDark, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          )),
          Text(value, style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          )),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          )),
          Text(value, style: GoogleFonts.inter(
            fontSize: isTotal ? 17 : 13,
            fontWeight: FontWeight.bold,
            color: color,
          )),
        ],
      ),
    );
  }
}
