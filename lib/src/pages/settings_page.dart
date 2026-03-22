import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/habit_notification_service.dart';
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

  bool _habitNotificationsEnabled = false;
  TimeOfDay _habitNotificationStart = const TimeOfDay(hour: 11, minute: 0);
  int _habitNotificationIntervalHours = 8;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notificationSettings = await HabitNotificationService.loadSettings();
    _habitNotificationsEnabled = notificationSettings.enabled;
    _habitNotificationStart = _timeFromMinutes(
      notificationSettings.startMinutes,
    );
    _habitNotificationIntervalHours = notificationSettings.intervalHours;

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

  TimeOfDay _timeFromMinutes(int totalMinutes) {
    final normalized = totalMinutes % (24 * 60);
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  int _minutesFromTime(TimeOfDay time) => (time.hour * 60) + time.minute;

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
    final notificationSettings = HabitNotificationSettings(
      enabled: _habitNotificationsEnabled,
      startMinutes: _minutesFromTime(_habitNotificationStart),
      intervalHours: _habitNotificationIntervalHours,
    );
    var remoteSaveSucceeded = false;

    try {
      if (notificationSettings.enabled) {
        final allowed = await HabitNotificationService.areNotificationsAllowed();
        final granted = allowed
            ? true
            : await HabitNotificationService.requestPermission();

        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notification permission is needed to show habit reminders.',
                ),
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }
      }

      await HabitNotificationService.saveSettings(notificationSettings);
      await HabitNotificationService.applySchedule(notificationSettings);

      await supabase.from('user_settings').upsert({
        'user_id': user.id,
        'theme_mode': themeStr,
        'font_family': _selectedFont,
        'office_start': _toStorage(_officeStart),
        'office_end': _toStorage(_officeEnd),
        'personal_start': _toStorage(_personalStart),
        'personal_end': _toStorage(_personalEnd),
      }, onConflict: 'user_id');
      remoteSaveSucceeded = true;

      // Apply theme immediately in app
      AppTheme.themeMode.value = _isDark ? ThemeMode.dark : ThemeMode.light;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              remoteSaveSucceeded
                  ? 'Settings saved'
                  : 'Habit reminders updated locally',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              remoteSaveSucceeded
                  ? 'Failed to finish saving: $e'
                  : 'Habit reminders updated locally, but cloud settings failed: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  final _fonts = ["Delius", "ShareTech", "Carattere", "HanaleiFill", "Outfit"];

  String _selectedFont = "Delius";

  List<String> _notificationPreview() {
    final results = <String>[];
    final startMinutes = _minutesFromTime(_habitNotificationStart);
    final nowMinutes = _minutesFromTime(TimeOfDay.fromDateTime(DateTime.now()));

    var nextMinutes = startMinutes;
    while (nextMinutes <= nowMinutes) {
      nextMinutes += _habitNotificationIntervalHours * 60;
    }

    for (var i = 0; i < 3; i++) {
      final totalMinutes = (nextMinutes + (i * _habitNotificationIntervalHours * 60)) %
          (24 * 60);
      results.add(
        MaterialLocalizations.of(context).formatTimeOfDay(
          _timeFromMinutes(totalMinutes),
          alwaysUse24HourFormat: false,
        ),
      );
    }

    return results;
  }

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

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isDark
                          ? const [Color(0xFF1A2440), Color(0xFF243A63)]
                          : const [Color(0xFFEFF5FF), Color(0xFFDDEBFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isDark
                          ? const Color(0xFF35507F)
                          : const Color(0xFFB9D2FF),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: _isDark
                                  ? const Color(0xFFB8CFFF)
                                  : const Color(0xFF2457C5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Habit reminder notifications',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Offline reminders that open the habits module directly.',
                                  style: TextStyle(
                                    color: _isDark
                                        ? const Color(0xFFC9D6F2)
                                        : const Color(0xFF35558A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable habit reminders'),
                        subtitle: const Text(
                          'Turn daily reminder notifications on or off.',
                        ),
                        value: _habitNotificationsEnabled,
                        onChanged: (value) {
                          setState(() => _habitNotificationsEnabled = value);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('First reminder time'),
                        subtitle: Text(
                          _formatTime(_habitNotificationStart),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _habitNotificationStart,
                          );
                          if (picked == null) return;
                          setState(() => _habitNotificationStart = picked);
                        },
                      ),
                      DropdownButtonFormField<int>(
                        value: _habitNotificationIntervalHours,
                        decoration: const InputDecoration(
                          labelText: 'Time between reminders',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(24, (index) => index + 1)
                            .map((hours) {
                              return DropdownMenuItem(
                                value: hours,
                                child: Text(
                                  '$hours hour${hours == 1 ? '' : 's'}',
                                ),
                              );
                            })
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _habitNotificationIntervalHours = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _notificationPreview().map((time) {
                          return Chip(
                            avatar: const Icon(Icons.alarm_rounded, size: 18),
                            label: Text(time),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preview shows the next reminders based on your current settings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isDark
                              ? const Color(0xFFB7C7E8)
                              : const Color(0xFF47648E),
                        ),
                      ),
                    ],
                  ),
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
