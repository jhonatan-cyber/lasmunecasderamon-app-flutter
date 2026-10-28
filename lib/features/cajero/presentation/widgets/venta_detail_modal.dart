import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';
import 'venta_format.dart';

/// Modal «Detalle de Venta» (hoja arrastrable): encabezado, datos de la
/// venta, productos y totales según `GET /ventas/{id}`.
class VentaDetailModal extends StatelessWidget {
  const VentaDetailModal({
    super.key,
    required this.loadingDetail,
    required this.selectedVenta,
    required this.onDismiss,
    required this.onClose,
  });

  final bool loadingDetail;
  final dynamic selectedVenta;

  /// Tap fuera de la hoja: limpia el detalle y cierra.
  final VoidCallback onDismiss;

  /// Botón «Cerrar Detalles».
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceColor
                      : AppTheme.lightSurfaceColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor,
                  ),
                ),
                child: loadingDetail
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : selectedVenta != null
                    ? _DetailContent(
                        venta: selectedVenta,
                        scrollController: scrollController,
                        onClose: onClose,
                      )
                    : const Center(child: Text('Error al cargar detalle')),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.venta,
    required this.scrollController,
    required this.onClose,
  });

  final dynamic venta;
  final ScrollController scrollController;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listItems = (venta['items'] as List<dynamic>?) ?? [];
    final double subtotal =
        double.tryParse(venta['subtotal']?.toString() ?? '0') ?? 0.0;
    final double descuento =
        double.tryParse(venta['descuento']?.toString() ?? '0') ?? 0.0;
    final double total =
        double.tryParse(venta['total']?.toString() ?? '0') ?? 0.0;
    final double propina =
        double.tryParse(venta['propina']?.toString() ?? '0') ?? 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de Venta',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Código: ${venta['codigo'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDetailInfoBox(
                      'Fecha/Hora',
                      formatVentaDateTime(venta['fecha_crea']),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDetailInfoBox(
                      'Método Pago',
                      (venta['metodo_pago']?.toString().toUpperCase() ??
                          'EFECTIVO'),
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailInfoBox(
                'Cliente',
                venta['cliente_nombre'] ?? 'Sin Cliente',
                isDark,
              ),
              if (venta['habitacion_nombre'] != null) ...[
                const SizedBox(height: 12),
                _buildDetailInfoBox(
                  'Habitación',
                  venta['habitacion_nombre'],
                  isDark,
                ),
              ],
              if (venta['tiempo'] != null) ...[
                const SizedBox(height: 12),
                _buildDetailInfoBox('Tiempo', '${venta['tiempo']} min', isDark),
              ],
              const SizedBox(height: 20),

              if (venta['pedido_id'] != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VENTA DESDE PEDIDO',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (venta['garzon_nombre'] != null)
                              Text(
                                'Garzón: ${venta['garzon_nombre']}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              Text(
                'PRODUCTOS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              ...listItems.map((item) {
                final double precio =
                    double.tryParse(item['precio']?.toString() ?? '0') ?? 0.0;
                final int qty =
                    int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorderColor
                          : AppTheme.lightBorderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CANT: $qty',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['producto_nombre'] ?? 'Producto',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(precio * qty),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor,
                  ),
                ),
                child: Column(
                  children: [
                    _buildPriceRow('Subtotal', formatCurrency(subtotal)),
                    if (propina > 0) ...[
                      const SizedBox(height: 4),
                      _buildPriceRow(
                        'Propina',
                        '+${formatCurrency(propina)}',
                        color: Colors.green,
                      ),
                    ],
                    if (descuento > 0) ...[
                      const SizedBox(height: 4),
                      _buildPriceRow(
                        'Descuento',
                        '- ${formatCurrency(descuento)}',
                        color: Colors.redAccent,
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          formatCurrency(total),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: onClose,
              child: Text(
                'Cerrar Detalles',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailInfoBox(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBgColor : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
