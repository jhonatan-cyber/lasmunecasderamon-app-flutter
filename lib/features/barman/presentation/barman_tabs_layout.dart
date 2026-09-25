import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/global_timer_alert.dart';
import '../../cajero/presentation/widgets/staff_call_overlay.dart';

/// Tabs del rol Barman, espejo de `app/(app)/barman/(tabs)/_layout.tsx` de la
/// app Expo: Asistencia · Anticipos · Inicio · Propinas · Horas Extras.
class BarmanTabsLayout extends StatelessWidget {
  final Widget child;

  const BarmanTabsLayout({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/barman/asistencia') return 0;
    if (location == '/barman/anticipos') return 1;
    if (location == '/barman') return 2;
    if (location == '/barman/propinas') return 3;
    if (location == '/barman/horas-extras') return 4;
    return 2;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/barman/asistencia');
        break;
      case 1:
        context.go('/barman/anticipos');
        break;
      case 2:
        context.go('/barman');
        break;
      case 3:
        context.go('/barman/propinas');
        break;
      case 4:
        context.go('/barman/horas-extras');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBarColor =
        isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            child,
            const StaffCallOverlay(),
            const GlobalTimerAlert(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppTheme.darkBorderColor
                    : AppTheme.lightBorderColor,
                width: 1.0,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onItemTapped(index, context),
            backgroundColor: navBarColor,
            indicatorColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.calendar_today_rounded,
                    color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.calendar_today_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Asistencia',
              ),
              NavigationDestination(
                icon: Icon(Icons.wallet_rounded,
                    color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.wallet_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Anticipos',
              ),
              NavigationDestination(
                icon:
                    Icon(Icons.home_rounded, color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.home_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.monetization_on_rounded,
                    color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.monetization_on_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Propinas',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_time_rounded,
                    color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.more_time_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Extras',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
