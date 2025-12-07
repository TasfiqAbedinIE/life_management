import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;

  // Theme
  bool _isDark = false;

  // Hours
  TimeOfDay? _officeStart;
  TimeOfDay? _officeEnd;
  TimeOfDay? _personalStart;
  TimeOfDay? _personalEnd;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final data = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        final theme = (data['theme_mode'] as String?) ?? 'light';
        _isDark = theme == 'dark';
        AppTheme.themeMode.value = _isDark ? ThemeMode.dark : ThemeMode.light;

        _selectedFont = data['font_family'] ?? 'Delius';
        AppTheme.fontFamily.value = _selectedFont;

        _officeStart = _parseTime(data['office_start'] as String?);
        _officeEnd = _parseTime(data['office_end'] as String?);
        _personalStart = _parseTime(data['personal_start'] as String?);
        _personalEnd = _parseTime(data['personal_end'] as String?);
      } else {
        _isDark = AppTheme.themeMode.value == ThemeMode.dark;
      }
    } catch (_) {
      // you can show error if you want
    } finally {
      setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseTime(String? text) {
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    return t.format(context);
  }

  String _toStorage(TimeOfDay? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(
    ValueChanged<TimeOfDay?> setter,
    TimeOfDay? initial,
  ) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? now,
    );
    if (picked != null) {
      setState(() => setter(picked));
    }
  }

  Future<void> _save() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    final themeStr = _isDark ? 'dark' : 'light';

    try {
      await supabase.from('user_settings').upsert({
        'user_id': user.id,
        'theme_mode': themeStr,
        'font_family': _selectedFont,
        'office_start': _toStorage(_officeStart),
        'office_end': _toStorage(_officeEnd),
        'personal_start': _toStorage(_personalStart),
        'personal_end': _toStorage(_personalEnd),
      }, onConflict: 'user_id');

      // Apply theme immediately in app
      AppTheme.themeMode.value = _isDark ? ThemeMode.dark : ThemeMode.light;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  final _fonts = ["Delius", "ShareTech", "Carattere", "HanaleiFill", "Outfit"];

  String _selectedFont = "Delius";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // THEME
                SwitchListTile(
                  title: const Text('Dark theme'),
                  subtitle: const Text('Switch between light and dark mode'),
                  value: _isDark,
                  onChanged: (val) {
                    setState(() => _isDark = val);
                    AppTheme.themeMode.value = val
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  },
                ),
                const SizedBox(height: 24),

                DropdownButtonFormField<String>(
                  value: _selectedFont,
                  decoration: const InputDecoration(
                    labelText: "Font Style",
                    border: OutlineInputBorder(),
                  ),
                  items: _fonts.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(f, style: TextStyle(fontFamily: f)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedFont = value);
                      AppTheme.fontFamily.value = value;
                    }
                  },
                ),

                const SizedBox(height: 24),

                const Text(
                  'Office Hours',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start'),
                        subtitle: Text(_formatTime(_officeStart)),
                        onTap: () =>
                            _pickTime((t) => _officeStart = t, _officeStart),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End'),
                        subtitle: Text(_formatTime(_officeEnd)),
                        onTap: () =>
                            _pickTime((t) => _officeEnd = t, _officeEnd),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Personal Focus Hours',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start'),
                        subtitle: Text(_formatTime(_personalStart)),
                        onTap: () => _pickTime(
                          (t) => _personalStart = t,
                          _personalStart,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End'),
                        subtitle: Text(_formatTime(_personalEnd)),
                        onTap: () =>
                            _pickTime((t) => _personalEnd = t, _personalEnd),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
    );
  }
}
