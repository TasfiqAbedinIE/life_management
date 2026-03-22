import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HabitNotificationSettings {
  final bool enabled;
  final int startMinutes;
  final int intervalHours;

  const HabitNotificationSettings({
    required this.enabled,
    required this.startMinutes,
    required this.intervalHours,
  });

  static const HabitNotificationSettings defaults = HabitNotificationSettings(
    enabled: false,
    startMinutes: 11 * 60,
    intervalHours: 8,
  );

  HabitNotificationSettings copyWith({
    bool? enabled,
    int? startMinutes,
    int? intervalHours,
  }) {
    return HabitNotificationSettings(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      intervalHours: intervalHours ?? this.intervalHours,
    );
  }
}

class HabitNotificationService {
  HabitNotificationService._();

  static const _enabledKey = 'habit_notifications_enabled';
  static const _startMinutesKey = 'habit_notifications_start_minutes';
  static const _intervalHoursKey = 'habit_notifications_interval_hours';

  static const _channel = MethodChannel(
    'task_management_app/habit_notifications',
  );

  static Future<HabitNotificationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return HabitNotificationSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      startMinutes:
          prefs.getInt(_startMinutesKey) ??
          HabitNotificationSettings.defaults.startMinutes,
      intervalHours:
          prefs.getInt(_intervalHoursKey) ??
          HabitNotificationSettings.defaults.intervalHours,
    );
  }

  static Future<void> saveSettings(HabitNotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setInt(_startMinutesKey, settings.startMinutes);
    await prefs.setInt(_intervalHoursKey, settings.intervalHours);
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
      'startMinutes': settings.startMinutes,
      'intervalHours': settings.intervalHours,
    });
  }

  static Future<String?> consumeLaunchDestination() {
    return _channel.invokeMethod<String>('consumeLaunchDestination');
  }
}
