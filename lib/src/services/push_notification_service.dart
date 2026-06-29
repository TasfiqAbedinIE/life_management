import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../coupled/couple_repository.dart';
import '../coupled/coupled_request_page.dart';
import '../coupled/love_pill_page.dart';
import 'habit_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialized by the Android process.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<AuthState>? _authSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  static bool _initialized = false;
  static RemoteMessage? _pendingNavigationMessage;
  static bool _navigationScheduled = false;

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await _registerCurrentToken();

    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((_) {
      unawaited(_registerCurrentToken());
    });

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageNavigation,
    );
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundLovePill,
    );

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessageNavigation(initialMessage);
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      unawaited(_registerCurrentToken());
      _schedulePendingNavigation();
    });
  }

  static Future<void> _registerCurrentToken() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await client.from('user_push_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }

  static Future<void> _showForegroundLovePill(RemoteMessage message) async {
    if (message.data['type'] != 'love_pill') return;

    final allowed =
        await HabitNotificationService.areNotificationsAllowed() ||
        await HabitNotificationService.requestPermission();
    if (!allowed) return;

    await HabitNotificationService.showCouplePillNotification(
      title: message.notification?.title ?? 'New love pill',
      message:
          message.notification?.body ??
          message.data['message'] ??
          'Your better half sent you something sweet.',
    );
  }

  static Future<void> _handleMessageNavigation(RemoteMessage message) async {
    final destination = message.data['destination'];
    final isLovePill =
        destination == 'love_pills' || message.data['type'] == 'love_pill';
    if (destination != 'coupled' && !isLovePill) return;

    _pendingNavigationMessage = message;
    _schedulePendingNavigation();
  }

  static void _schedulePendingNavigation() {
    if (_pendingNavigationMessage == null || _navigationScheduled) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      unawaited(_openPendingNavigation());
    });
  }

  static Future<void> _openPendingNavigation() async {
    final message = _pendingNavigationMessage;
    if (message == null) return;

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _schedulePendingNavigation();
      return;
    }
    if (Supabase.instance.client.auth.currentSession == null) {
      return;
    }

    final destination = message.data['destination'];
    final isLovePill =
        destination == 'love_pills' || message.data['type'] == 'love_pill';

    Widget page = const CoupledRequestPage();
    if (isLovePill) {
      final repo = CoupleRepository(Supabase.instance.client);
      final couple = await repo.fetchExistingCouple();
      final coupleId = couple?['id']?.toString();
      if (couple?['status'] == 'active' && coupleId != null) {
        page = LovePillPage(coupleId: coupleId, repo: repo);
      }
    }

    if (!identical(_pendingNavigationMessage, message)) return;
    _pendingNavigationMessage = null;
    navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _pendingNavigationMessage = null;
    _navigationScheduled = false;
    _initialized = false;
  }
}
