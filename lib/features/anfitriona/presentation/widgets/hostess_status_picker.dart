import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HostessStatusPicker extends StatelessWidget {
  final int userStatus;
  final ValueChanged<int> onStatusChange;

  const HostessStatusPicker({
    super.key,
    required this.userStatus,
    required this.onStatusChange,
  });

  String _getStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Disponible';
      case 2:
        return 'En Servicio';
      case 3:
        return 'Descanso';
      default:
        return 'Desconocido';
    }
  }

  Color _getStatusColor(int status, bool isDark) {
    switch (status) {
      case 1:
        return const Color(0xFF10B981); // Emerald/Green
      case 2:
        return const Color(0xFFEF4444); // Red
      case 3:
        return const Color(0xFFF59E0B); // Amber/Yellow
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : Colors.grey.shade300;
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final buttons = [1, 2, 3].map((status) {
      final isSelected = userStatus == status;
      final color = _getStatusColor(status, isDark);
      final label = _getStatusLabel(status);

      return Expanded(
        child: InkWell(
          onTap: () => onStatusChange(status),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? color : borderColor,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : textSecondary,
              ),
            ),
          ),
        ),
      );
    }).toList();

    final List<Widget> rowChildren = [];
    for (int i = 0; i < buttons.length; i++) {
      rowChildren.add(buttons[i]);
      if (i < buttons.length - 1) {
        rowChildren.add(const SizedBox(width: 10));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(children: rowChildren),
    );
  }
}
