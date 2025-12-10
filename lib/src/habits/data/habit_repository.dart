// lib/features/habits/data/habit_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';

class HabitRepository {
  final SupabaseClient client;

  HabitRepository(this.client);

  Future<List<Habit>> fetchHabits() async {
    final data = await client
        .from('habits')
        .select('*')
        .isFilter('archived_at', null)
        .order('created_at');

    return (data as List)
        .map((e) => Habit.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // 🔹 UPDATED: remove userId param, get from auth.currentUser
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

  Future<void> archiveHabit(String habitId) async {
    await client
        .from('habits')
        .update({'archived_at': DateTime.now().toIso8601String()})
        .eq('id', habitId);
  }

  /// Fetch entries for last [days] days for a habit
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

    // (Optional nicety) Use only the date part for a DATE column:
    final fromDateStr = from.toIso8601String().substring(0, 10);

    final data = await client
        .from('habit_entries')
        .select('*')
        .eq('habit_id', habitId)
        .gte('entry_date', fromDateStr)
        .order('entry_date');

    return (data as List)
        .map((e) => HabitEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Toggle today's completion:
  /// if already done (>= frequencyPerDay) → reset to 0
  /// else → set done_count = frequencyPerDay
  Future<void> toggleToday({required Habit habit}) async {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);

    // DATE column → keep only 'YYYY-MM-DD'
    final dateStr = dateOnly.toIso8601String().substring(0, 10);

    // Get existing entry for today
    final existing = await client
        .from('habit_entries')
        .select('*')
        .eq('habit_id', habit.id)
        .eq('entry_date', dateStr)
        .maybeSingle();

    int newDoneCount;
    if (existing != null) {
      final currentCount = existing['done_count'] as int? ?? 0;
      if (currentCount >= habit.frequencyPerDay) {
        newDoneCount = 0;
      } else {
        newDoneCount = habit.frequencyPerDay;
      }
    } else {
      newDoneCount = habit.frequencyPerDay;
    }

    // If resetting to 0, we can delete the row for cleanliness
    if (newDoneCount == 0 && existing != null) {
      await client
          .from('habit_entries')
          .delete()
          .eq('id', existing['id'] as String);
    } else {
      await client.from('habit_entries').upsert({
        'habit_id': habit.id,
        'entry_date': dateStr,
        'done_count': newDoneCount,
      }, onConflict: 'habit_id,entry_date');
    }
  }
}
