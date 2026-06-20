import 'habit.dart';
import 'habit_entry.dart';

class HabitStreak {
  final int current;
  final int best;

  const HabitStreak({required this.current, required this.best});
}

class HabitStreakCalculator {
  const HabitStreakCalculator._();

  static HabitStreak calculate({
    required Habit habit,
    required List<HabitEntry> entries,
    DateTime? today,
    int weeks = 52,
  }) {
    final date = _dateOnly(today ?? DateTime.now());
    final entryCounts = <DateTime, int>{
      for (final entry in entries) _dateOnly(entry.entryDate): entry.doneCount,
    };
    final currentWeekStart = date.subtract(Duration(days: date.weekday - 1));
    final completedWeeks = <bool>[];

    for (var offset = 0; offset < weeks; offset++) {
      final weekStart = currentWeekStart.subtract(Duration(days: offset * 7));
      final scheduledDates = habit.scheduledWeekdays
          .map((weekday) => weekStart.add(Duration(days: weekday - 1)))
          .toList();
      final hasFutureOccurrence = scheduledDates.any(
        (day) => day.isAfter(date),
      );
      if (offset == 0 && hasFutureOccurrence) continue;

      completedWeeks.add(
        scheduledDates.every(
          (day) => (entryCounts[day] ?? 0) >= habit.frequencyPerDay,
        ),
      );
    }

    var current = 0;
    for (final completed in completedWeeks) {
      if (!completed) break;
      current++;
    }

    var best = 0;
    var run = 0;
    for (final completed in completedWeeks) {
      run = completed ? run + 1 : 0;
      if (run > best) best = run;
    }
    return HabitStreak(current: current, best: best);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
