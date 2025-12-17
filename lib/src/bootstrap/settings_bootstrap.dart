import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class SettingsBootstrap extends StatefulWidget {
  final Widget child;
  const SettingsBootstrap({super.key, required this.child});

  @override
  State<SettingsBootstrap> createState() => _SettingsBootstrapState();
}

class _SettingsBootstrapState extends State<SettingsBootstrap> {
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // Load once on start (if session exists)
    _applySettings();

    // Also re-apply after login/logout
    _client.auth.onAuthStateChange.listen((_) {
      _applySettings();
    });
  }

  Future<void> _applySettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _client
          .from('user_settings')
          .select('theme_mode, font_family')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data == null) return;

      final theme = (data['theme_mode'] as String?) ?? 'light';
      final font = (data['font_family'] as String?) ?? 'Poppins';

      AppTheme.themeMode.value = (theme == 'dark')
          ? ThemeMode.dark
          : ThemeMode.light;
      AppTheme.fontFamily.value = font;
    } catch (_) {
      // optional: log error
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
