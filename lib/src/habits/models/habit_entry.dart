// lib/features/habits/models/habit_entry.dart
class HabitEntry {
  final String id;
  final String habitId;
  final DateTime entryDate;
  final int doneCount;
  final DateTime createdAt;

  HabitEntry({
    required this.id,
    required this.habitId,
    required this.entryDate,
    required this.doneCount,
    required this.createdAt,
  });

  factory HabitEntry.fromMap(Map<String, dynamic> map) {
    return HabitEntry(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      entryDate: DateTime.parse(map['entry_date'] as String),
      doneCount: map['done_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'habit_id': habitId,
      'entry_date': entryDate.toIso8601String(),
      'done_count': doneCount,
    };
  }
}
