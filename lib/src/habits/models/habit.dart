// lib/features/habits/models/habit.dart
class Habit {
  static const allWeekdays = <int>[1, 2, 3, 4, 5, 6, 7];

  final String id;
  final String userId;
  final String name;
  final int frequencyPerDay;
  final List<int> scheduledWeekdays;
  final String? colorHex;
  final DateTime createdAt;
  final DateTime? archivedAt;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.frequencyPerDay,
    this.scheduledWeekdays = allWeekdays,
    this.colorHex,
    required this.createdAt,
    this.archivedAt,
  });

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      frequencyPerDay: map['frequency_per_day'] as int? ?? 1,
      scheduledWeekdays: _parseWeekdays(map['scheduled_weekdays']),
      colorHex: map['color_hex'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'name': name,
      'frequency_per_day': frequencyPerDay,
      'scheduled_weekdays': scheduledWeekdays,
      'color_hex': colorHex,
    };
  }

  bool isScheduledOn(DateTime date) => scheduledWeekdays.contains(date.weekday);

  static List<int> _parseWeekdays(dynamic value) {
    if (value is! List) return allWeekdays;
    final weekdays = value.whereType<num>().map((day) => day.toInt()).toSet()
      ..removeWhere((day) => day < 1 || day > 7);
    if (weekdays.isEmpty) return allWeekdays;
    final sorted = weekdays.toList()..sort();
    return List.unmodifiable(sorted);
  }
}
