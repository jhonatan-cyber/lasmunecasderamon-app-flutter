import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../data/solicitud_item.dart';
import 'solicitud_constants.dart';

class SolicitudCard extends StatelessWidget {
  final SolicitudItem item;
  final bool cajaAbierta;
  final VoidCallback? onAprobarAnticipo;
  final VoidCallback? onRechazar;
  final VoidCallback? onAbrirCheckout;
  final VoidCallback? onAbrirServiceModal;

  const SolicitudCard({
    super.key,
    required this.item,
    required this.cajaAbierta,
    this.onAprobarAnticipo,
    this.onRechazar,
    this.onAbrirCheckout,
    this.onAbrirServiceModal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSrv = item.tipoItem == 'solicitud';
    final isAnt = item.tipoItem == 'anticipo';
    final color = solicitudTypeColor(item, context);
    final icon = solicitudTypeIcon(item);
    final typeLabel = solicitudTypeLabel(item);

    final timeStr = DateFormat('hh:mm a').format(item.fechaOrden);
    final elapsedMinutes = DateTime.now().difference(item.fechaOrden).inMinutes;
    final isUrgent = elapsedMinutes >= 5 && !isAnt;

    final placeLabel = solicitudPlaceLabel(item);
    final requestByLabel = solicitudRequestByLabel(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isUrgent
              ? Colors.redAccent
              : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
          width: isUrgent ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isSrv) {
            onAbrirServiceModal?.call();
          } else if (isAnt) {
            if (item.estado == 1) {
              onAprobarAnticipo?.call();
            }
          } else {
            onAbrirCheckout?.call();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Código: ${item.codigo}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formatCurrency(item.monto),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.black.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      isDark, Icons.bed_outlined, placeLabel,
                      isUrgent: false,
                    ),
                    const SizedBox(height: 6),
                    _detailRow(
                      isDark, Icons.person_outline_rounded, requestByLabel,
                      isUrgent: false,
                    ),
                    const SizedBox(height: 6),
                    _detailRow(
                      isDark, Icons.access_time_rounded,
                      '$timeStr (${formatElapsedTime(item.fechaOrden)})',
                      isUrgent: isUrgent,
                    ),

                    
                    if (isAnt) ...[
                      const SizedBox(height: 10),
                      _anticipoStateBadge(isDark),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              
              _actionButtons(context, isDark, isAnt, isSrv, color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(bool isDark, IconData icon, String text, {required bool isUrgent}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isUrgent
              ? Colors.redAccent
              : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isUrgent ? FontWeight.bold : FontWeight.w600,
              color: isUrgent
                  ? Colors.redAccent
                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _anticipoStateBadge(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.estado == 1
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.estado == 1
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.blue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.estado == 1
                ? '✓ Aprobado por Administración'
                : '⏳ Esperando Respuesta Admin',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: item.estado == 1 ? Colors.green : Colors.blueAccent,
            ),
          ),
          if (item.motivo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.motivo,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButtons(
    BuildContext context,
    bool isDark,
    bool isAnt,
    bool isSrv,
    Color color,
  ) {
    if (isAnt) {
      return _anticipoActions(context, isDark);
    }

    return _defaultActions(context, isDark, isSrv, color);
  }

  Widget _anticipoActions(BuildContext context, bool isDark) {
    if (item.estado == 2) {
      
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'En Autorización',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: !cajaAbierta ? null : onAprobarAnticipo,
        icon: const Icon(Icons.check_rounded, size: 16),
        label: Text(
          'Entregar Efectivo',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _defaultActions(
    BuildContext context,
    bool isDark,
    bool isSrv,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                foregroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: !cajaAbierta ? null : onRechazar,
              child: Text(
                'Rechazar',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: !cajaAbierta
                  ? null
                  : () {
                      if (isSrv) {
                        onAbrirServiceModal?.call();
                      } else {
                        onAbrirCheckout?.call();
                      }
                    },
              child: Text(
                'Aprobar',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
