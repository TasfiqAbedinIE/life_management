import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../coupled/coupled_request_page.dart';

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
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  static bool _initialized = false;

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

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageNavigation(initialMessage);
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      unawaited(_registerCurrentToken());
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

  static void _handleMessageNavigation(RemoteMessage message) {
    final destination = message.data['destination'];
    if (destination != 'coupled') return;

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(builder: (_) => const CoupledRequestPage()),
    );
  }

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _initialized = false;
  }
}
