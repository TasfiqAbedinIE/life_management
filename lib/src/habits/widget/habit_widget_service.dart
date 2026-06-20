import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap/app_bootstrap.dart';
import '../data/habit_repository.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';
import '../presentation/habits_page.dart';

class HabitWidgetService {
  HabitWidgetService._();

  static const String _widgetProviderName = 'HabitWidgetProvider';
  static const String _qualifiedAndroidName =
      'com.example.task_management_app.HabitWidgetProvider';
  static const String _launchAction = 'open-habits';
  static const int _maxVisibleHabits = 3;

  static bool _launchRequested = false;
  static bool _launchListening = false;

  static Future<void> initialize() async {
    await HomeWidget.registerInteractivityCallback(backgroundCallback);

    if (_launchListening) return;
    _launchListening = true;

    HomeWidget.widgetClicked.listen(_handleLaunchUri);
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleLaunchUri(initialUri);
  }

  static void _handleLaunchUri(Uri? uri) {
    if (uri == null) return;
    if (uri.host == _launchAction) {
      _launchRequested = true;
    }
  }

  static void consumeLaunchIntent(BuildContext context) {
    if (!_launchRequested) return;

    _launchRequested = false;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HabitsPage()));
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    try {
      if (uri == null) return;

      await AppBootstrap.ensureInitialized(allowAssetLoad: false);

      final repo = HabitRepository(Supabase.instance.client);
      final action = uri.queryParameters['action'];
      final habitId = uri.queryParameters['habitId'];

      if (action == null || habitId == null || habitId.isEmpty) {
        await sync(repository: repo);
        return;
      }

      final habits = await repo.fetchHabits();
      Habit? habit;
      for (final item in habits) {
        if (item.id == habitId) {
          habit = item;
          break;
        }
      }

      if (habit == null) {
        await sync(repository: repo, habits: habits);
        return;
      }

      if (action == 'increment') {
        await repo.incrementToday(habit: habit);
      } else if (action == 'decrement') {
        await repo.decrementToday(habit: habit);
      } else if (action == 'toggle') {
        await repo.toggleTodayFull(habit: habit);
      }

      await sync(repository: repo, habits: habits);
    } catch (_) {
      await _saveInteractionFallbackState();
    }
  }

  static Future<void> sync({
    HabitRepository? repository,
    List<Habit>? habits,
  }) async {
    await AppBootstrap.ensureInitialized();

    final client = Supabase.instance.client;
    final repo = repository ?? HabitRepository(client);
    final user = client.auth.currentUser;

    if (user == null) {
      await _saveEmptyState(message: 'Sign in to track today\'s habits.');
      return;
    }

    final resolvedHabits = habits ?? await repo.fetchHabits();
    if (resolvedHabits.isEmpty) {
      await _saveEmptyState(message: 'Create a habit to start your streak.');
      return;
    }

    final entriesMap = await repo.fetchEntriesForHabits(
      habitIds: resolvedHabits.map((habit) => habit.id).toList(),
      days: 1,
    );

    final visibleHabits = resolvedHabits.take(_maxVisibleHabits).toList();
    final todayKey = _dateKey(DateTime.now());
    final rows = visibleHabits.map((habit) {
      final done = _todayDone(entriesMap[habit.id] ?? [], todayKey);
      return _HabitWidgetRow(
        id: habit.id,
        name: habit.name,
        done: done,
        target: habit.frequencyPerDay,
        enabled: habit.isScheduledOn(DateTime.now()),
        colorHex: habit.colorHex ?? _fallbackColorFor(habit.name),
      );
    }).toList();

    final scheduledToday = resolvedHabits.where(
      (habit) => habit.isScheduledOn(DateTime.now()),
    );
    final totalCompleted = scheduledToday.where((habit) {
      final done = _todayDone(entriesMap[habit.id] ?? [], todayKey);
      return done >= habit.frequencyPerDay;
    }).length;

    final summary = scheduledToday.isEmpty
        ? 'No habits scheduled today'
        : '$totalCompleted of ${scheduledToday.length} scheduled habits complete';

    await HomeWidget.saveWidgetData<String>('habit_widget_date', todayKey);
    await HomeWidget.saveWidgetData<String>('habit_widget_summary', summary);
    await HomeWidget.saveWidgetData<int>('habit_widget_total', rows.length);
    await HomeWidget.saveWidgetData<String>('habit_widget_empty_message', '');

    for (var index = 0; index < _maxVisibleHabits; index++) {
      final row = index < rows.length ? rows[index] : null;
      await HomeWidget.saveWidgetData<String>(
        'habit_row_${index}_id',
        row?.id ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_row_${index}_name',
        row?.name ?? '',
      );
      await HomeWidget.saveWidgetData<int>(
        'habit_row_${index}_done',
        row?.done ?? 0,
      );
      await HomeWidget.saveWidgetData<int>(
        'habit_row_${index}_target',
        row?.target ?? 0,
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_row_${index}_color',
        row?.colorHex ?? '#6D7CFF',
      );
      await HomeWidget.saveWidgetData<bool>(
        'habit_row_${index}_enabled',
        row?.enabled ?? false,
      );
    }

    await _updateWidget();
  }

  static Future<void> _saveEmptyState({required String message}) async {
    final todayKey = _dateKey(DateTime.now());
    await HomeWidget.saveWidgetData<String>('habit_widget_date', todayKey);
    await HomeWidget.saveWidgetData<String>(
      'habit_widget_summary',
      'No habits yet',
    );
    await HomeWidget.saveWidgetData<int>('habit_widget_total', 0);
    await HomeWidget.saveWidgetData<String>(
      'habit_widget_empty_message',
      message,
    );

    for (var index = 0; index < _maxVisibleHabits; index++) {
      await HomeWidget.saveWidgetData<String>('habit_row_${index}_id', '');
      await HomeWidget.saveWidgetData<String>('habit_row_${index}_name', '');
      await HomeWidget.saveWidgetData<int>('habit_row_${index}_done', 0);
      await HomeWidget.saveWidgetData<int>('habit_row_${index}_target', 0);
      await HomeWidget.saveWidgetData<String>(
        'habit_row_${index}_color',
        '#6D7CFF',
      );
      await HomeWidget.saveWidgetData<bool>(
        'habit_row_${index}_enabled',
        false,
      );
    }

    await _updateWidget();
  }

  static Future<void> _saveInteractionFallbackState() async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'habit_widget_summary',
        'Open the app to refresh habits',
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_widget_empty_message',
        'Tap Open and sync your habits again.',
      );
      await _updateWidget();
    } catch (_) {
      // Ignore background widget failures to avoid crashing the host process.
    }
  }

  static Future<void> _updateWidget() async {
    await HomeWidget.updateWidget(
      name: _widgetProviderName,
      androidName: _widgetProviderName,
      qualifiedAndroidName: _qualifiedAndroidName,
    );
  }

  static int _todayDone(List<HabitEntry> entries, String todayKey) {
    for (final entry in entries) {
      if (_dateKey(entry.entryDate) == todayKey) {
        return entry.doneCount;
      }
    }
    return 0;
  }

  static String _fallbackColorFor(String input) {
    const palette = ['#FF7A59', '#F7B500', '#00B894', '#3B82F6', '#7C5CFF'];

    final hash = input.codeUnits.fold<int>(0, (sum, char) => sum + char);
    return palette[hash % palette.length];
  }

  static String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _HabitWidgetRow {
  final String id;
  final String name;
  final int done;
  final int target;
  final bool enabled;
  final String colorHex;

  const _HabitWidgetRow({
    required this.id,
    required this.name,
    required this.done,
    required this.target,
    required this.enabled,
    required this.colorHex,
  });
}
