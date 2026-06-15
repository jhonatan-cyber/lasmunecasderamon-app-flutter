import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class PremiumHeaderTab {
  final String id;
  final String label;

  const PremiumHeaderTab({required this.id, required this.label});
}

class PremiumHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showBackButton;
  final bool showAddButton;
  final VoidCallback? onAdd;
  final String? addLabel;
  final List<PremiumHeaderTab>? tabs;
  final String? activeTabId;
  final ValueChanged<String>? onTabChanged;
  final bool showRefreshButton;
  final bool isRefreshing;
  final VoidCallback? onRefresh;
  final bool? connectionStatus; // null = hidden, true = connected, false = disconnected
  final String? connectionLabel;
  final Widget? rightWidget;
  final String? centerTitle;
  final double bottomPadding;

  const PremiumHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showBackButton = false,
    this.showAddButton = false,
    this.onAdd,
    this.addLabel,
    this.tabs,
    this.activeTabId,
    this.onTabChanged,
    this.showRefreshButton = false,
    this.isRefreshing = false,
    this.onRefresh,
    this.connectionStatus,
    this.connectionLabel,
    this.rightWidget,
    this.centerTitle,
    this.bottomPadding = 25.0,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            Color(0xFF881337),
            Color(0xFF1A0B10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40D84315),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: bottomPadding,
          ),
          child: Column(
            children: [
              // Top row: back button, title, actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (showBackButton && onBack != null)
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: isTablet ? 20 : 18,
                        ),
                      ),
                    ),

                  // Title
                  Expanded(
                    child: Text(
                      centerTitle ?? title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // Right widget (custom) or refresh button or add button
                  if (rightWidget != null)
                    rightWidget!
                  else if (showRefreshButton)
                    GestureDetector(
                      onTap: isRefreshing ? null : onRefresh,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: isRefreshing
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    )
                  else if (showAddButton)
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              addLabel ?? 'Nuevo',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 38),
                ],
              ),

              // Subtitle row
              if (subtitle != null) ...[
                const SizedBox(height: 20),
                Text(
                  subtitle!,
                  style: GoogleFonts.outfit(
                    fontSize: isTablet ? 24 : 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Connection status or subtitle description
                if (connectionStatus != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: connectionStatus! ? Colors.greenAccent : Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (connectionStatus! ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        connectionLabel ??
                            (connectionStatus! ? 'Conectado' : 'Desconectado'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],

              // Tabs row
              if (tabs != null && tabs!.isNotEmpty) ...[
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tabs!.map((tab) {
                      final isActive = activeTabId == tab.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onTabChanged != null
                              ? () => onTabChanged!(tab.id)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              tab.label,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
