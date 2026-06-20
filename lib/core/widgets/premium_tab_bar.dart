import 'package:flutter/material.dart';





class PremiumTabBar extends StatelessWidget {
  const PremiumTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    this.indicatorColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.isScrollable = false,
  });

  final List<PremiumTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? indicatorColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = this.indicatorColor ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: isScrollable
          ? _buildScrollableTabBar(context, indicatorColor)
          : _buildTabBar(context, indicatorColor),
    );
  }

  Widget _buildTabBar(BuildContext context, Color indicatorColor) {
    return Row(
      children: tabs.asMap().entries.map((entry) {
        final i = entry.key;
        final tab = entry.value;
        final isSelected = i == currentIndex;

        return Expanded(
          child: _buildTabItem(context, tab, isSelected, indicatorColor, () => onTap(i)),
        );
      }).toList(),
    );
  }

  Widget _buildScrollableTabBar(BuildContext context, Color indicatorColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final tab = entry.value;
          final isSelected = i == currentIndex;

          return _buildTabItem(context, tab, isSelected, indicatorColor, () => onTap(i));
        }).toList(),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context,
    PremiumTab tab,
    bool isSelected,
    Color indicatorColor,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final effectiveLabelStyle = isSelected
        ? (labelStyle ??
            TextStyle(
              color: indicatorColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ))
        : (unselectedLabelStyle ??
            TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? indicatorColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (tab.icon != null) ...[
              Icon(
                tab.icon,
                size: 18,
                color: effectiveLabelStyle.color,
              ),
              const SizedBox(width: 6),
            ],
            if (tab.badge != null)
              Badge(
                label: Text(
                  tab.badge!,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: indicatorColor,
                child: Text(tab.label, style: effectiveLabelStyle),
              )
            else
              Text(tab.label, style: effectiveLabelStyle),
          ],
        ),
      ),
    );
  }
}


class PremiumTab {
  final String label;
  final IconData? icon;
  final String? badge;

  const PremiumTab({
    required this.label,
    this.icon,
    this.badge,
  });
}
