import 'habit.dart';
import 'habit_entry.dart';

class HabitPerformance {
  final Map<String, int> completedUnitsByDay;
  final Map<String, int> targetUnitsByDay;

  const HabitPerformance({
    required this.completedUnitsByDay,
    required this.targetUnitsByDay,
  });

  Map<String, double> get completionByDay => {
    for (final entry in targetUnitsByDay.entries)
      entry.key: entry.value == 0
          ? 0
          : (completedUnitsByDay[entry.key] ?? 0) / entry.value,
  };

  double percentForLastDays(DateTime today, int days) {
    var completed = 0;
    var target = 0;
    final date = DateTime(today.year, today.month, today.day);
    for (var offset = 0; offset < days; offset++) {
      final key = dateKey(date.subtract(Duration(days: offset)));
      completed += completedUnitsByDay[key] ?? 0;
      target += targetUnitsByDay[key] ?? 0;
    }
    return target == 0 ? 0 : completed / target * 100;
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class HabitPerformanceCalculator {
  const HabitPerformanceCalculator._();

  static HabitPerformance calculate({
    required List<Habit> habits,
    required List<HabitEntry> entries,
    DateTime? today,
    int days = 28,
  }) {
    final end = today ?? DateTime.now();
    final endDate = DateTime(end.year, end.month, end.day);
    final doneByDay = <String, Map<String, int>>{};
    for (final entry in entries) {
      final key = HabitPerformance.dateKey(entry.entryDate);
      doneByDay.putIfAbsent(key, () => {})[entry.habitId] = entry.doneCount;
    }

    final completedByDay = <String, int>{};
    final targetByDay = <String, int>{};
    for (var offset = days - 1; offset >= 0; offset--) {
      final date = endDate.subtract(Duration(days: offset));
      final key = HabitPerformance.dateKey(date);
      var completed = 0;
      var target = 0;
      for (final habit in habits) {
        if (!habit.isScheduledOn(date)) continue;
        target += habit.frequencyPerDay;
        final done = doneByDay[key]?[habit.id] ?? 0;
        completed += done.clamp(0, habit.frequencyPerDay);
      }
      completedByDay[key] = completed;
      targetByDay[key] = target;
    }

    return HabitPerformance(
      completedUnitsByDay: completedByDay,
      targetUnitsByDay: targetByDay,
    );
  }
}
