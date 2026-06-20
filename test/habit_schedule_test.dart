import 'package:flutter_test/flutter_test.dart';
import 'package:task_management_app/src/habits/models/habit.dart';
import 'package:task_management_app/src/habits/models/habit_entry.dart';
import 'package:task_management_app/src/habits/models/habit_performance.dart';
import 'package:task_management_app/src/habits/models/habit_streak.dart';

void main() {
  Habit habit({List<int> weekdays = const [3, 6, 7]}) => Habit(
    id: 'habit-1',
    userId: 'user-1',
    name: 'Exercise',
    frequencyPerDay: 3,
    scheduledWeekdays: weekdays,
    createdAt: DateTime(2026),
  );

  HabitEntry entry(DateTime date, [int count = 3]) => HabitEntry(
    id: date.toIso8601String(),
    habitId: 'habit-1',
    entryDate: date,
    doneCount: count,
    createdAt: date,
  );

  test('missing schedule data defaults existing habits to every day', () {
    final parsed = Habit.fromMap({
      'id': 'habit-1',
      'user_id': 'user-1',
      'name': 'Read',
      'frequency_per_day': 1,
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(parsed.scheduledWeekdays, Habit.allWeekdays);
    expect(parsed.isScheduledOn(DateTime(2026, 6, 20)), isTrue);
  });

  test('counts a streak only when every scheduled day reaches its target', () {
    final entries = [
      entry(DateTime(2026, 6, 10)),
      entry(DateTime(2026, 6, 13)),
      entry(DateTime(2026, 6, 14)),
      entry(DateTime(2026, 6, 17)),
      entry(DateTime(2026, 6, 20)),
      entry(DateTime(2026, 6, 21)),
    ];

    final streak = HabitStreakCalculator.calculate(
      habit: habit(),
      entries: entries,
      today: DateTime(2026, 6, 21),
    );

    expect(streak.current, 2);
    expect(streak.best, 2);
  });

  test('does not evaluate the current week before its last scheduled day', () {
    final entries = [
      entry(DateTime(2026, 6, 10)),
      entry(DateTime(2026, 6, 13)),
      entry(DateTime(2026, 6, 14)),
      entry(DateTime(2026, 6, 17)),
    ];

    final streak = HabitStreakCalculator.calculate(
      habit: habit(),
      entries: entries,
      today: DateTime(2026, 6, 18),
    );

    expect(streak.current, 1);
  });

  test('an under-target scheduled day breaks the weekly streak', () {
    final entries = [
      entry(DateTime(2026, 6, 10)),
      entry(DateTime(2026, 6, 13), 2),
      entry(DateTime(2026, 6, 14)),
    ];

    final streak = HabitStreakCalculator.calculate(
      habit: habit(),
      entries: entries,
      today: DateTime(2026, 6, 14),
    );

    expect(streak.current, 0);
  });

  test('habit performance is weighted by scheduled repetition targets', () {
    final saturdayHabit = habit(weekdays: const [6]);
    final sundayHabit = Habit(
      id: 'habit-2',
      userId: 'user-1',
      name: 'Plan week',
      frequencyPerDay: 1,
      scheduledWeekdays: const [7],
      createdAt: DateTime(2026),
    );
    final entries = [
      entry(DateTime(2026, 6, 20), 2),
      HabitEntry(
        id: 'sunday-entry',
        habitId: 'habit-2',
        entryDate: DateTime(2026, 6, 21),
        doneCount: 1,
        createdAt: DateTime(2026, 6, 21),
      ),
    ];

    final performance = HabitPerformanceCalculator.calculate(
      habits: [saturdayHabit, sundayHabit],
      entries: entries,
      today: DateTime(2026, 6, 21),
      days: 7,
    );

    expect(performance.completionByDay['2026-06-20'], closeTo(2 / 3, 0.001));
    expect(performance.completionByDay['2026-06-21'], 1);
    expect(performance.percentForLastDays(DateTime(2026, 6, 21), 7), 75);
  });

  test('unscheduled days do not reduce habit performance', () {
    final performance = HabitPerformanceCalculator.calculate(
      habits: [
        habit(weekdays: const [6]),
      ],
      entries: [entry(DateTime(2026, 6, 20), 3)],
      today: DateTime(2026, 6, 21),
      days: 7,
    );

    expect(performance.targetUnitsByDay['2026-06-21'], 0);
    expect(performance.percentForLastDays(DateTime(2026, 6, 21), 7), 100);
  });
}
