import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';


class VentaTabs extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final int? activeTimerCount;
  final bool isDark;

  const VentaTabs({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    this.activeTimerCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              label: 'Historial',
              isActive: activeTab == 'historial',
              onTap: () => onTabChanged('historial'),
              primaryColor: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTab(
              label: 'Ventas con Habitación',
              isActive: activeTab == 'proceso',
              badge: activeTimerCount,
              onTap: () => onTabChanged('proceso'),
              primaryColor: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color primaryColor,
    int? badge,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isActive
              ? null
              : Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (badge != null && badge > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
