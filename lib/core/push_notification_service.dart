import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'api_client.dart';
import 'utils/deep_links.dart';






final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();







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

  
  
  

  
  
  
  
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await Firebase.initializeApp();
    _initialiseLocalNotifications();
    _setupForegroundHandler();

    
    
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      
      Future.microtask(() => _handleNotificationTap(initialMessage));
    }

    
    await _registerForPushNotifications();

    
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  
  
  Future<void> _registerForPushNotifications() async {
    
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
      
      
      return;
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      
      return;
    }

    
    final token = await messaging.getToken();
    if (token != null && token != _currentFcmToken) {
      _currentFcmToken = token;
      await _saveTokenToServer(token);
    }

    
    messaging.onTokenRefresh.listen((newToken) {
      _currentFcmToken = newToken;
      _saveTokenToServer(newToken);
    });
  }

  
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
      
      
    }
  }

  
  
  

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
      _triggerNotificationEffects(message);
    });
  }

  
  
  

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
        
        
        final payload = response.payload;
        if (payload != null) {
          _handleNotificationPayload(payload);
        }
      },
    );

    
    
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

  
  
  

  void _triggerNotificationEffects(RemoteMessage message) {
    final data = message.data;
    final isPriority = data['priority'] == 'true' ||
        data['type'] == 'staff_call' ||
        data['type'] == 'timer_ended';

    
    if (isPriority) {
      HapticFeedback.heavyImpact();
      
    } else {
      HapticFeedback.mediumImpact();
    }

    
    
  }

  
  
  

  void _handleNotificationTap(RemoteMessage message) {
    _handleNotificationPayload(message.data.toString());
  }

  void _handleNotificationPayload(String payload) {
    
    
    final type = _extractType(payload);

    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateByNotificationType(type);
    });
  }

  String? _extractType(String payload) {
    
    try {
      
      final typeMatch = RegExp(r'type[=:]\s*"([^"]+)"').firstMatch(payload);
      return typeMatch?.group(1);
    } catch (_) {
      return null;
    }
  }

  void _navigateByNotificationType(String? type) async {
    if (type == null) return;

    
    final context = pushNavigatorKey.currentContext;
    if (context == null) return;

    
    String? role;
    if (type.contains('staff') || type.contains('request') || type.contains('sale')) {
      role = 'cajero';
    } else if (type.contains('approved') || type.contains('processed')) {
      role = 'garzon';
    }

    
    final route = DeepLinks.fromNotificationType(type, null, role: role);

    if (context.mounted && route != '/') {
      context.go(route);
    }
  }
}







@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  
  
  
}
