import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';

class ServiceCard extends StatelessWidget {
  final dynamic item;
  final int index;
  final ValueChanged<dynamic> onPress;
  final Function(String, String, String) onAssistance;

  const ServiceCard({
    super.key,
    required this.item,
    required this.index,
    required this.onPress,
    required this.onAssistance,
  });

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      try {
        final cleaned = dateStr.trim().replaceAll(' ', 'T');
        return DateTime.parse(cleaned).toLocal();
      } catch (_) {
        return null;
      }
    }
  }

  String _formatDate(String? dateStr) {
    final date = _parseDate(dateStr);
    if (date == null) return 'Sin fecha';
    try {
      return DateFormat('dd/MM/yyyy', 'es_ES').format(date);
    } catch (_) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  String _formatTime(String? dateStr) {
    final date = _parseDate(dateStr);
    if (date == null) return '';
    try {
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.gray500Color;
    final borderColor = isDark ? accentColor.withValues(alpha: 0.25) : Colors.grey.shade200;

    final estadoNum = int.tryParse(item['estado']?.toString() ?? '0') ?? 0;
    final isProceso = estadoNum == 2;

    final statusMap = {
      0: _StatusInfo(
        bg: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
        text: isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
        label: 'Anulado',
      ),
      1: _StatusInfo(
        bg: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE),
        text: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF),
        label: 'Por Cobrar',
      ),
      2: _StatusInfo(
        bg: isDark ? const Color(0xFF7C2D12) : const Color(0xFFFEF3C7),
        text: isDark ? const Color(0xFFFDBA74) : const Color(0xFF92400E),
        label: 'En Proceso',
      ),
      3: _StatusInfo(
        bg: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
        text: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        label: 'Pausado',
      ),
      4: _StatusInfo(
        bg: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
        text: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF),
        label: 'Solicitud Anul.',
      ),
    };

    final status = statusMap[estadoNum] ??
        _StatusInfo(bg: Colors.grey, text: Colors.white, label: 'Desconocido');

    final String habitacion = item['habitacion']?.toString() ?? 'Sin Habitación';
    final String codigo = item['codigo']?.toString() ?? '----';
    final double comision = double.tryParse(item['comision_usuario']?.toString() ?? '0') ?? 0.0;
    final String idServicio = item['id_servicio']?.toString() ?? '';
    final String fechaCrea = item['fecha_crea']?.toString() ?? '';
    final String cliente = item['cliente']?.toString() ?? 'Sin cliente';
    final int tiempo = int.tryParse(item['tiempo']?.toString() ?? '0') ?? 0;

    final formatter = NumberFormat.decimalPattern('es_ES');

    return Card(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      margin: const EdgeInsets.only(top: 10, left: 16, right: 16),
      elevation: 0,
      child: InkWell(
        onTap: () => onPress(item),
        borderRadius: BorderRadius.circular(16),
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
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        habitacion,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: status.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(fechaCrea),
                    style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time_outlined, size: 12, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(fechaCrea),
                    style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                  ),
                  if (tiempo > 0) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.timer_outlined, size: 12, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$tiempo min',
                      style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      cliente,
                      style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Código:',
                        style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                      ),
                      Text(
                        codigo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Mi Comisión:',
                        style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                      ),
                      Text(
                        '\$${formatter.format(comision)}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isProceso) ...[
                const SizedBox(height: 15),
                Container(
                  height: 1,
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 10),
                Text(
                  'SILENT ASSISTANCE:',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildAssistanceButton(
                        context: context,
                        icon: Icons.local_bar_outlined,
                        label: 'Tragos',
                        btnBg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFE0E7FF),
                        textColor: accentColor,
                        onPressed: () => onAssistance(idServicio, habitacion, 'Tragos'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildAssistanceButton(
                        context: context,
                        icon: Icons.clean_hands_outlined,
                        label: 'Servicio',
                        btnBg: isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFD1FAE5),
                        textColor: const Color(0xFF10B981),
                        onPressed: () => onAssistance(idServicio, habitacion, 'Limpieza/Hielo'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildAssistanceButton(
                        context: context,
                        icon: Icons.warning_amber_rounded,
                        label: 'ALERTA',
                        btnBg: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                        textColor: const Color(0xFFEF4444),
                        onPressed: () => onAssistance(idServicio, habitacion, 'Seguridad'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistanceButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color btnBg,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusInfo {
  final Color bg;
  final Color text;
  final String label;

  _StatusInfo({
    required this.bg,
    required this.text,
    required this.label,
  });
}
