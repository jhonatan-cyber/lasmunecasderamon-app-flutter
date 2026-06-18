import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'api_client.dart';
import 'utils/deep_links.dart';

/// Global key used by the notification service to access the router
/// for deep‑linking navigation.
///
/// Set this in [PushNotificationService.init] or from your app's root
/// navigator key.
final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();

/// Handles all push notification lifecycle:
/// - FCM initialisation & permissions
/// - Token registration with the backend
/// - Foreground / background / terminated state messages
/// - Deep‑link navigation on tap
/// - Local notifications via [flutter_local_notifications]
@visibleForTesting
class PushNotificationService {
  PushNotificationService({
    required this.apiClientProvider,
  });

  final ApiClient Function() apiClientProvider;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  String? _currentFcmToken;

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Initialise Firebase, request permissions, register token, and set up
  /// all listeners (foreground, background, terminated, tap).
  ///
  /// Must be called once, after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await Firebase.initializeApp();
    _initialiseLocalNotifications();
    _setupForegroundHandler();

    // Handle the case where the app was opened from a terminated state
    // via a notification tap.
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Defer navigation to let the app finish building its widget tree.
      Future.microtask(() => _handleNotificationTap(initialMessage));
    }

    // Register for remote notifications (permissions + token).
    await _registerForPushNotifications();

    // Background message handler (static top‑level, registered here).
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Tap handler when the app is in background.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// Request notification permissions and register the FCM token with the
  /// backend. Also listens for token refresh.
  Future<void> _registerForPushNotifications() async {
    // ── Permissions ───────────────────────────────────────────────────
    final messaging = FirebaseMessaging.instance;

    NotificationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        criticalAlert: true,
      );
    } else {
      settings = await messaging.requestPermission();
    }

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      // The user hasn't decided yet — this usually means the dialog was
      // not shown on Android. Noop — we'll retry on next app launch.
      return;
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // Permission denied — can't get a token.
      return;
    }

    // ── Token ─────────────────────────────────────────────────────────
    final token = await messaging.getToken();
    if (token != null && token != _currentFcmToken) {
      _currentFcmToken = token;
      await _saveTokenToServer(token);
    }

    // Listen for token refresh and re‑register.
    messaging.onTokenRefresh.listen((newToken) {
      _currentFcmToken = newToken;
      _saveTokenToServer(newToken);
    });
  }

  /// Save (or update) the FCM token on the backend.
  Future<void> _saveTokenToServer(String token) async {
    try {
      final api = apiClientProvider();
      await api.dio.post(
        '/notifications',
        data: {
          'token': token,
          'device_type': defaultTargetPlatform.name,
        },
      );
    } catch (_) {
      // Token registration failure is non‑critical — will retry on next
      // app launch or token refresh.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Foreground handler
  // ─────────────────────────────────────────────────────────────────────────

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
      _triggerNotificationEffects(message);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local notifications (displayed while app is in foreground)
  // ─────────────────────────────────────────────────────────────────────────

  void _initialiseLocalNotifications() {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // When a local notification is tapped while the app is in
        // foreground, parse the payload and navigate.
        final payload = response.payload;
        if (payload != null) {
          _handleNotificationPayload(payload);
        }
      },
    );

    // Android notification channel (must be created for local notifications
    // to appear on Android 8+).
    _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'default_channel',
            'Notificaciones',
            description: 'Notificaciones de Las Muñecas de Ramón',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if (title == null && body == null) return;

    final data = message.data;
    final payload = data.isNotEmpty ? data.toString() : null;

    _localNotifications.show(
      id: title.hashCode ^ body.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Notificaciones',
          channelDescription: 'Notificaciones de Las Muñecas de Ramón',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Effects (haptics + TTS — mirrors Expo's triggerNotificationEffects)
  // ─────────────────────────────────────────────────────────────────────────

  void _triggerNotificationEffects(RemoteMessage message) {
    final data = message.data;
    final isPriority = data['priority'] == 'true' ||
        data['type'] == 'staff_call' ||
        data['type'] == 'timer_ended';

    // Haptic / vibration feedback
    if (isPriority) {
      HapticFeedback.heavyImpact();
      // Extended vibration is handled by the Android/iOS channel config.
    } else {
      HapticFeedback.mediumImpact();
    }

    // TTS is not implemented on Flutter (no expo-speech equivalent).
    // If needed in the future, add `flutter_tts` package here.
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Deep‑link navigation
  // ─────────────────────────────────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    _handleNotificationPayload(message.data.toString());
  }

  void _handleNotificationPayload(String payload) {
    // The payload is data.toString() from Firebase data.
    // We parse it to determine the route.
    final type = _extractType(payload);

    // Run navigation on the next frame so the widget tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateByNotificationType(type);
    });
  }

  String? _extractType(String payload) {
    // Try to parse as JSON map.
    try {
      // Simple key=value parsing for now.
      final typeMatch = RegExp(r'type[=:]\s*"([^"]+)"').firstMatch(payload);
      return typeMatch?.group(1);
    } catch (_) {
      return null;
    }
  }

  void _navigateByNotificationType(String? type) async {
    if (type == null) return;

    // Use the global navigator key to get context and navigate.
    final context = pushNavigatorKey.currentContext;
    if (context == null) return;

    // Determine user role for deep-link routing
    String? role;
    if (type.contains('staff') || type.contains('request') || type.contains('sale')) {
      role = 'cajero';
    } else if (type.contains('approved') || type.contains('processed')) {
      role = 'garzon';
    }

    // Map notification types to routes using centralized DeepLinks util
    final route = DeepLinks.fromNotificationType(type, null, role: role);

    if (context.mounted && route != '/') {
      context.go(route);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background handler (top‑level, required by firebase_messaging)
// ─────────────────────────────────────────────────────────────────────────────

/// This must be a top‑level function (not a method) because
/// `firebase_messaging` will spawn it in a separate isolate.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // In the background isolate we can't access the navigator or show
  // local notifications directly. Firebase + OS will show the system
  // notification automatically.
}
