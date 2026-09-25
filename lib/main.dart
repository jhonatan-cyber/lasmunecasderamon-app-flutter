import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/global_messenger.dart';
import 'core/push_notification_service.dart';
import 'core/sse_dispatcher.dart';
import 'features/auth/data/auth_notifier.dart';


const _sentryDsn =
    String.fromEnvironment('SENTRY_DSN',
        defaultValue: 'https://placeholder@example.ingest.sentry.io/placeholder');

Future<void> main() async {
  // Carga los datos de formato de fecha de TODOS los locales: la app usa
  // DateFormat(..., 'es_ES'/'es'/'es_CL') y sin inicializarlos las pantallas
  // que lo usan (Asistencia, Administrativo, comisiones…) revientan con
  // LocaleDataException ("Locale data has not been initialized").
  await initializeDateFormatting();
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      runApp(const ProviderScope(child: MyApp()));
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Único listener global de los 36 eventos SSE del catálogo del dashboard.
    ref.watch(sseDispatcherProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accentTheme = ref.watch(accentColorProvider);
    final primaryColor = accentTheme.color;

    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            ui.PlatformDispatcher.instance.platformBrightness ==
                ui.Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return _PushNotificationBootstrap(
      child: MaterialApp.router(
        title: 'Las Muñecas de Ramón',
        scaffoldMessengerKey: globalMessengerKey,
        theme: AppTheme.getTheme(Brightness.light, primaryColor),
        darkTheme: AppTheme.getTheme(Brightness.dark, primaryColor),
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}





class _PushNotificationBootstrap extends ConsumerStatefulWidget {
  const _PushNotificationBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_PushNotificationBootstrap> createState() =>
      _PushNotificationBootstrapState();
}

class _PushNotificationBootstrapState
    extends ConsumerState<_PushNotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    _initPushNotifications();
  }

  void _initPushNotifications() {
    final service = PushNotificationService(
      apiClientProvider: () => ref.read(apiClientProvider),
    );
    service.init();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
