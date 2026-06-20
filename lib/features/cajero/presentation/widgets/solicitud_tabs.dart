import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';

class SolicitudTabs extends StatelessWidget {
  final String activeFilter;
  final int totalCount;
  final int anticipoCount;
  final int pedidoCount;
  final int solicitudCount;
  final ValueChanged<String> onFilterChanged;

  const SolicitudTabs({
    super.key,
    required this.activeFilter,
    required this.totalCount,
    required this.anticipoCount,
    required this.pedidoCount,
    required this.solicitudCount,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTab(context, 'all', 'Todas', totalCount),
          const SizedBox(width: 8),
          _buildTab(context, 'anticipo', 'Anticipos', anticipoCount),
          const SizedBox(width: 8),
          _buildTab(context, 'pedido', 'Pedidos', pedidoCount),
          const SizedBox(width: 8),
          _buildTab(context, 'solicitud', 'Servicios', solicitudCount),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String filter, String label, int count) {
    final isSelected = activeFilter == filter;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onFilterChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : (isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
