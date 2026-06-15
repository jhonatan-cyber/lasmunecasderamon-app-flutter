import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}



class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accentTheme = ref.watch(accentColorProvider);
    final primaryColor = accentTheme.color;

    return MaterialApp.router(
      title: 'Las Muñecas de Ramón',
      theme: AppTheme.getTheme(Brightness.light, primaryColor),
      darkTheme: AppTheme.getTheme(Brightness.dark, primaryColor),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
