import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HabitNotificationSettings {
  final bool enabled;

  const HabitNotificationSettings({required this.enabled});
}

class HabitNotificationService {
  HabitNotificationService._();

  static const _enabledKey = 'habit_notifications_enabled';

  static const _channel = MethodChannel(
    'task_management_app/habit_notifications',
  );

  static Future<HabitNotificationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return HabitNotificationSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
    );
  }

  static Future<void> saveSettings(HabitNotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
  }

  static Future<bool> areNotificationsAllowed() async {
    final allowed =
        await _channel.invokeMethod<bool>('areNotificationsAllowed') ?? true;
    return allowed;
  }

  static Future<bool> requestPermission() async {
    final granted =
        await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        true;
    return granted;
  }

  static Future<void> applySchedule(HabitNotificationSettings settings) async {
    await _channel.invokeMethod('configureHabitNotifications', {
      'enabled': settings.enabled,
    });
  }

  static Future<void> showCouplePillNotification({
    required String title,
    required String message,
  }) async {
    await _channel.invokeMethod('showCouplePillNotification', {
      'title': title,
      'message': message,
    });
  }

  static Future<String?> consumeLaunchDestination() {
    return _channel.invokeMethod<String>('consumeLaunchDestination');
  }
}
