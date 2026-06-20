import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';


class CuentaTabs extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final bool isDark;
  final int totalCount;
  final int pendingCount;

  const CuentaTabs({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.isDark,
    required this.totalCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _buildTab('todas', 'Todas', totalCount, primaryColor)),
          const SizedBox(width: 8),
          Expanded(child: _buildTab('pendientes', 'Pendientes', pendingCount, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildTab(String tabId, String label, int count, Color primaryColor) {
    final isActive = activeTab == tabId;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTabChanged(tabId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? null
              : Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.white : primaryColor,
                  ),
                ),
              ),
            if (count > 0) const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
