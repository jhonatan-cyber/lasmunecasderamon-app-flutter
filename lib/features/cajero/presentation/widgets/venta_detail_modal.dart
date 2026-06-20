import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../domain/venta_model.dart';
import 'venta_constants.dart';


class VentaDetailModal extends StatelessWidget {
  final VentaDetail ventaDetail;
  final bool isDark;
  final VoidCallback onClose;

  const VentaDetailModal({
    super.key,
    required this.ventaDetail,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
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
                  color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                  ),
                ),
                child: _buildContent(scrollController, context),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController, BuildContext context) {
    final v = ventaDetail;
    final primaryColor = Theme.of(context).colorScheme.primary;

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
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Código: ${v.codigo}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
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
                  Expanded(child: _infoBox('Fecha/Hora', formatDateTime(v.fechaCrea), isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _infoBox('Método Pago', v.metodoPago, isDark)),
                ],
              ),
              const SizedBox(height: 12),
              _infoBox('Cliente', v.clienteNombre, isDark),
              if (v.habitacionNombre != null) ...[
                const SizedBox(height: 12),
                _infoBox('Habitación', v.habitacionNombre!, isDark),
              ],
              if (v.tiempo != null) ...[
                const SizedBox(height: 12),
                _infoBox('Tiempo', '${v.tiempo} min', isDark),
              ],
              const SizedBox(height: 20),

              
              if (v.pedidoId != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_outlined, color: primaryColor, size: 20),
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
                                color: primaryColor,
                              ),
                            ),
                            if (v.garzonNombre != null)
                              Text(
                                'Garzón: ${v.garzonNombre}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              if (v.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Sin productos registrados',
                      style: GoogleFonts.inter(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...v.items.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CANT: ${item.cantidad}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.productoNombre,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        formatCurrency(item.precio * item.cantidad),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),

              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                  ),
                ),
                child: Column(
                  children: [
                    _priceRow('Subtotal', formatCurrency(v.subtotal)),
                    if (v.propina > 0) ...[
                      const SizedBox(height: 4),
                      _priceRow('Propina', '+${formatCurrency(v.propina)}', color: Colors.green),
                    ],
                    if (v.descuento > 0) ...[
                      const SizedBox(height: 4),
                      _priceRow('Descuento', '- ${formatCurrency(v.descuento)}', color: Colors.redAccent),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TOTAL', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900)),
                        Text(
                          formatCurrency(v.total),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
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
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: onClose,
              child: Text(
                'Cerrar Detalles',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoBox(String label, String value, bool isDark) {
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
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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

  Widget _priceRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13)),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
