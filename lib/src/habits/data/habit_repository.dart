// lib/features/habits/data/habit_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';

class HabitRepository {
  final SupabaseClient client;

  HabitRepository(this.client);

  // --- helpers ---
  String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  String _todayKey() => _dateKey(DateTime.now());

  // --- habits ---
  Future<List<Habit>> fetchHabits() async {
    final data = await client
        .from('habits')
        .select('*')
        .isFilter('archived_at', null) // or .eq('archived_at', null)
        .order('created_at');

    return (data as List)
        .map((e) => Habit.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Habit> createHabit({
    required String name,
    required int frequencyPerDay,
    String? colorHex,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('No logged-in user found when creating habit.');
    }

    final insertMap = {
      'user_id': user.id, // uuid from auth.users
      'name': name,
      'frequency_per_day': frequencyPerDay,
      'color_hex': colorHex,
    };

    final data = await client
        .from('habits')
        .insert(insertMap)
        .select()
        .single();
    return Habit.fromMap(data as Map<String, dynamic>);
  }

  Future<Habit> updateHabit({
    required String habitId,
    required String name,
    required int frequencyPerDay,
    String? colorHex,
  }) async {
    final data = await client
        .from('habits')
        .update({
          'name': name,
          'frequency_per_day': frequencyPerDay,
          'color_hex': colorHex,
        })
        .eq('id', habitId)
        .select()
        .single();

    return Habit.fromMap(data as Map<String, dynamic>);
  }

  Future<void> archiveHabit(String habitId) async {
    await client
        .from('habits')
        .update({'archived_at': DateTime.now().toIso8601String()})
        .eq('id', habitId);
  }

  /// HARD delete habit
  /// ✅ habit_entries will delete automatically if your FK has ON DELETE CASCADE
  Future<void> deleteHabit(String habitId) async {
    await client.from('habits').delete().eq('id', habitId);
  }

  // --- entries ---
  Future<List<HabitEntry>> fetchEntriesForHabit({
    required String habitId,
    int days = 30,
  }) async {
    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final fromDateStr = _dateKey(from);

    final data = await client
        .from('habit_entries')
        .select('*')
        .eq('habit_id', habitId)
        .gte('entry_date', fromDateStr) // entry_date is DATE
        .order('entry_date');

    return (data as List)
        .map((e) => HabitEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getTodayDoneCount(String habitId) async {
    final existing = await client
        .from('habit_entries')
        .select('done_count')
        .eq('habit_id', habitId)
        .eq('entry_date', _todayKey())
        .maybeSingle();

    return (existing?['done_count'] as int?) ?? 0;
  }

  /// Set today's done_count to exact value (0..frequencyPerDay)
  Future<void> setTodayDoneCount({
    required Habit habit,
    required int newCount,
  }) async {
    final clamped = newCount.clamp(0, habit.frequencyPerDay);
    final today = _todayKey();

    if (clamped == 0) {
      // Clean delete if 0
      await client
          .from('habit_entries')
          .delete()
          .eq('habit_id', habit.id)
          .eq('entry_date', today);
      return;
    }

    await client.from('habit_entries').upsert({
      'habit_id': habit.id,
      'entry_date': today,
      'done_count': clamped,
    }, onConflict: 'habit_id,entry_date');
  }

  Future<void> incrementToday({required Habit habit}) async {
    final current = await getTodayDoneCount(habit.id);
    await setTodayDoneCount(habit: habit, newCount: current + 1);
  }

  Future<void> decrementToday({required Habit habit}) async {
    final current = await getTodayDoneCount(habit.id);
    await setTodayDoneCount(habit: habit, newCount: current - 1);
  }

  /// Optional: quick full-done toggle (100% or reset)
  Future<void> toggleTodayFull({required Habit habit}) async {
    final current = await getTodayDoneCount(habit.id);
    final isFull = current >= habit.frequencyPerDay;
    await setTodayDoneCount(
      habit: habit,
      newCount: isFull ? 0 : habit.frequencyPerDay,
    );
  }

  Future<Map<String, List<HabitEntry>>> fetchEntriesForHabits({
    required List<String> habitIds,
    int days = 30,
  }) async {
    if (habitIds.isEmpty) return {};

    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final fromDateStr =
        '${from.year.toString().padLeft(4, '0')}-'
        '${from.month.toString().padLeft(2, '0')}-'
        '${from.day.toString().padLeft(2, '0')}';

    final data = await client
        .from('habit_entries')
        .select('*')
        .inFilter('habit_id', habitIds) // ✅ supabase-flutter v2
        .gte('entry_date', fromDateStr)
        .order('entry_date');

    final map = <String, List<HabitEntry>>{};
    for (final row in (data as List)) {
      final entry = HabitEntry.fromMap(row as Map<String, dynamic>);
      (map[entry.habitId] ??= []).add(entry);
    }
    return map;
  }
}
