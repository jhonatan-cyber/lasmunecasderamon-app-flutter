import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../cajero/presentation/widgets/staff_call_overlay.dart';

class AnfitrionaTabsLayout extends ConsumerWidget {
  final Widget child;

  const AnfitrionaTabsLayout({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/anfitriona/servicios') return 0;
    if (location == '/anfitriona/comisiones') return 1;
    if (location == '/anfitriona/asistencia') return 3;
    if (location == '/anfitriona/anticipos') return 4;
    // Default to Center (Inicio) if it's '/anfitriona'
    return 2;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/anfitriona/servicios');
        break;
      case 1:
        context.go('/anfitriona/comisiones');
        break;
      case 2:
        context.go('/anfitriona');
        break;
      case 3:
        context.go('/anfitriona/asistencia');
        break;
      case 4:
        context.go('/anfitriona/anticipos');
        break;
    }
  }

  Widget _buildTabItem({
    required int index,
    required int selectedIndex,
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    final isSelected = index == selectedIndex;
    final isCenter = index == 2;
    
    final activeColor = Colors.white;
    final inactiveColor = Colors.white.withValues(alpha: 0.55);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index, context),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isCenter ? 10 : 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: isCenter ? 26 : 22,
                ),
              ),
              if (!isCenter && label != 'Inicio') ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _getSelectedIndex(context);
    
    // Gradiente premium alineado a la marca
    final accentTheme = ref.watch(accentColorProvider);
    final gradientColors = accentTheme.gradient;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: gradientColors.last,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            child,
            const StaffCallOverlay(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTabItem(
                        index: 0,
                        selectedIndex: selectedIndex,
                        icon: Icons.favorite_rounded,
                        label: 'Servicios',
                        context: context,
                      ),
                      _buildTabItem(
                        index: 1,
                        selectedIndex: selectedIndex,
                        icon: Icons.wallet_rounded,
                        label: 'Ventas',
                        context: context,
                      ),
                      _buildTabItem(
                        index: 2,
                        selectedIndex: selectedIndex,
                        icon: Icons.home_rounded,
                        label: 'Inicio',
                        context: context,
                      ),
                      _buildTabItem(
                        index: 3,
                        selectedIndex: selectedIndex,
                        icon: Icons.calendar_today_rounded,
                        label: 'Asistencia',
                        context: context,
                      ),
                      _buildTabItem(
                        index: 4,
                        selectedIndex: selectedIndex,
                        icon: Icons.credit_card_rounded,
                        label: 'Anticipos',
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
