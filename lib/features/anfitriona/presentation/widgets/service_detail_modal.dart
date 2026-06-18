import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';

class ServiceDetailModal extends StatelessWidget {
  final dynamic servicio;
  final bool visible;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  const ServiceDetailModal({
    super.key,
    required this.servicio,
    required this.visible,
    required this.onClose,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (visible && servicio != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        show(context: context, servicio: servicio, onEdit: onEdit).then((_) => onClose());
      });
    }
    return const SizedBox.shrink();
  }

  static Future<void> show({
    required BuildContext context,
    required dynamic servicio,
    VoidCallback? onEdit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final bg = isDark ? Colors.black : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.gray500Color;
    final borderColor = isDark ? accentColor.withValues(alpha: 0.25) : Colors.grey.shade200;

    final estadoNum = int.tryParse(servicio['estado']?.toString() ?? '0') ?? 0;
    final double habitacionComision = double.tryParse(servicio['habitacion_comision']?.toString() ?? '0') ?? 0.0;
    final bool mostrarBotonEditar = habitacionComision > 0 && estadoNum == 2;

    final formatter = NumberFormat.decimalPattern('es_ES');
    
    _EstadoBadge getEstadoBadge(int estado) {
      switch (estado) {
        case 0:
          return _EstadoBadge(label: 'ANULADO', color: AppTheme.errorColor);
        case 1:
          return _EstadoBadge(label: 'FINALIZADO', color: AppTheme.successColor);
        case 2:
          return _EstadoBadge(label: 'EN PROCESO', color: AppTheme.infoColor);
        case 3:
          return _EstadoBadge(label: 'PAUSADO', color: AppTheme.warningColor);
        case 4:
          return _EstadoBadge(label: 'SOL. ANULACIÓN', color: const Color(0xFFF97316));
        default:
          return _EstadoBadge(label: 'DESCONOCIDO', color: AppTheme.gray500Color);
      }
    }

    final estadoBadge = getEstadoBadge(estadoNum);

    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
      try {
        final date = DateTime.parse(dateStr).toLocal();
        return DateFormat('dd/MM/yyyy hh:mm a', 'es_ES').format(date);
      } catch (_) {
        return 'Error';
      }
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detalle del Servicio',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  '#${servicio['codigo'] ?? ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: estadoBadge.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: estadoBadge.color, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: estadoBadge.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  estadoBadge.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: estadoBadge.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildGridItem(
                                width: (MediaQuery.of(context).size.width - 50) / 2,
                                icon: Icons.business,
                                label: 'HABITACIÓN',
                                value: servicio['habitacion']?.toString() ?? '',
                                bg: bg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                                iconColor: Theme.of(context).colorScheme.primary,
                              ),
                              _buildGridItem(
                                width: (MediaQuery.of(context).size.width - 50) / 2,
                                icon: Icons.timer,
                                label: 'TIEMPO',
                                value: '${servicio['tiempo'] ?? ''} min',
                                bg: bg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                                iconColor: Theme.of(context).colorScheme.primary,
                              ),
                              _buildGridItem(
                                width: MediaQuery.of(context).size.width - 40,
                                icon: Icons.person,
                                label: 'CLIENTE',
                                value: servicio['cliente']?.toString() ?? 'Sin registrar',
                                bg: bg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                                iconColor: Theme.of(context).colorScheme.primary,
                              ),
                              _buildGridItem(
                                width: MediaQuery.of(context).size.width - 40,
                                icon: Icons.people,
                                label: 'ANFITRIONAS',
                                value: servicio['anfitriona']?.toString() ?? 'No asignada',
                                bg: bg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                                iconColor: Theme.of(context).colorScheme.primary,
                              ),
                              _buildGridItem(
                                width: (MediaQuery.of(context).size.width - 50) / 2,
                                icon: Icons.credit_card,
                                label: 'MÉTODO PAGO',
                                value: (servicio['metodo_pago']?.toString() ?? 'efectivo').toUpperCase(),
                                bg: bg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                                iconColor: Theme.of(context).colorScheme.primary,
                              ),
                              _buildGridItem(
                                width: (MediaQuery.of(context).size.width - 50) / 2,
                                icon: Icons.calendar_today,
                                label: 'FECHA',
                                value: formatDate(servicio['fecha_crea']),
                                bg: bg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                                iconColor: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RESUMEN FINANCIERO',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: textSecondary,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryRow(
                                  label: 'Precio Servicio',
                                  val: '\$${formatter.format(double.tryParse(servicio['precio_servicio']?.toString() ?? '0') ?? 0.0)}',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                                const SizedBox(height: 8),
                                _buildSummaryRow(
                                  label: 'Precio Habitación',
                                  val: '\$${formatter.format(double.tryParse(servicio['precio_habitacion']?.toString() ?? '0') ?? 0.0)}',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Container(height: 1, color: borderColor),
                                const SizedBox(height: 12),
                                _buildSummaryRow(
                                  label: 'TOTAL SERVICIO',
                                  val: '\$${formatter.format(double.tryParse(servicio['total']?.toString() ?? '0') ?? 0.0)}',
                                  textPrimary: accentColor,
                                  textSecondary: textPrimary,
                                  isTotal: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (habitacionComision > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.successColor),
                              ),
                              child: _buildSummaryRow(
                                label: 'Comisión Habitación',
                                val: '\$${formatter.format(habitacionComision)}',
                                textPrimary: AppTheme.successColor,
                                textSecondary: AppTheme.successColor,
                                isBold: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: accentColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.diamond_outlined, size: 32, color: accentColor),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MI COMISIÓN',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: accentColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${formatter.format(double.tryParse(servicio['comision_usuario']?.toString() ?? '0') ?? 0.0)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          if (mostrarBotonEditar && onEdit != null) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.infoColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.edit, size: 20),
                                label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onEdit();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _buildGridItem({
    required double width,
    required IconData icon,
    required String label,
    required String value,
    required Color bg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, color: textPrimary, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static Widget _buildSummaryRow({
    required String label,
    required String val,
    required Color textPrimary,
    required Color textSecondary,
    bool isTotal = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 14 : 12,
            fontWeight: (isTotal || isBold) ? FontWeight.bold : FontWeight.normal,
            color: textSecondary,
          ),
        ),
        Text(
          val,
          style: isTotal
              ? GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                )
              : GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: (isTotal || isBold) ? FontWeight.bold : FontWeight.normal,
                  color: textPrimary,
                ),
        ),
      ],
    );
  }
}

class _EstadoBadge {
  final String label;
  final Color color;

  _EstadoBadge({
    required this.label,
    required this.color,
  });
}
