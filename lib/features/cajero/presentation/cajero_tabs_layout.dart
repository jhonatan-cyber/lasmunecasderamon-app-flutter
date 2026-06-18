import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/global_timer_alert.dart';
import 'widgets/staff_call_overlay.dart';

class CajeroTabsLayout extends StatelessWidget {
  final Widget child;

  const CajeroTabsLayout({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/cajero/asistencia') return 0;
    if (location == '/cajero/anticipos') return 1;
    if (location == '/cajero') return 2;
    if (location == '/cajero/propinas') return 3;
    if (location == '/cajero/mis-horas-extras') return 4;
    return 2; 
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/cajero/asistencia');
        break;
      case 1:
        context.go('/cajero/anticipos');
        break;
      case 2:
        context.go('/cajero');
        break;
      case 3:
        context.go('/cajero/propinas');
        break;
      case 4:
        context.go('/cajero/mis-horas-extras');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBarColor = isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
                color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                width: 1.0,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onItemTapped(index, context),
            backgroundColor: navBarColor,
            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.calendar_today_rounded, color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.calendar_today_rounded, color: Theme.of(context).colorScheme.primary),
                label: 'Asistencia',
              ),
              NavigationDestination(
                icon: Icon(Icons.wallet_rounded, color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.wallet_rounded, color: Theme.of(context).colorScheme.primary),
                label: 'Anticipos',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_rounded, color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.home_rounded, color: Theme.of(context).colorScheme.primary),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.monetization_on_rounded, color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.monetization_on_rounded, color: Theme.of(context).colorScheme.primary),
                label: 'Propinas',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_time_rounded, color: AppTheme.darkTextSecondary),
                selectedIcon: Icon(Icons.more_time_rounded, color: Theme.of(context).colorScheme.primary),
                label: 'Extras',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
