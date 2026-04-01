import 'package:shared_preferences/shared_preferences.dart';

/// Stores first-launch onboarding state locally on the device.
class OnboardingPreferences {
  OnboardingPreferences._();

  static const String _hasSeenOnboardingKey = 'hasSeenOnboarding';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }
}
