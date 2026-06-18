import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../cajero/presentation/widgets/staff_call_overlay.dart';

class GarzonTabsLayout extends StatelessWidget {
  final Widget child;

  const GarzonTabsLayout({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/garzon/asistencia') return 1;
    if (location == '/garzon/anticipos') return 2;
    if (location == '/garzon/propinas') return 3;
    if (location == '/garzon/horas-extras') return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/garzon');
        break;
      case 1:
        context.go('/garzon/asistencia');
        break;
      case 2:
        context.go('/garzon/anticipos');
        break;
      case 3:
        context.go('/garzon/propinas');
        break;
      case 4:
        context.go('/garzon/horas-extras');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBarColor = isDark
        ? AppTheme.darkSurfaceColor
        : AppTheme.lightSurfaceColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(children: [child, const StaffCallOverlay()]),
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
            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.home_rounded,
                  color: AppTheme.darkTextSecondary,
                ),
                selectedIcon: Icon(
                  Icons.home_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.darkTextSecondary,
                ),
                selectedIcon: Icon(
                  Icons.calendar_today_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Asistencia',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.wallet_rounded,
                  color: AppTheme.darkTextSecondary,
                ),
                selectedIcon: Icon(
                  Icons.wallet_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Anticipos',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.monetization_on_rounded,
                  color: AppTheme.darkTextSecondary,
                ),
                selectedIcon: Icon(
                  Icons.monetization_on_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Propinas',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.more_time_rounded,
                  color: AppTheme.darkTextSecondary,
                ),
                selectedIcon: Icon(
                  Icons.more_time_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Extras',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
