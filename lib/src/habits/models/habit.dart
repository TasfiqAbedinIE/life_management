// lib/features/habits/models/habit.dart
class Habit {
  final String id;
  final String userId;
  final String name;
  final int frequencyPerDay;
  final String? colorHex;
  final DateTime createdAt;
  final DateTime? archivedAt;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.frequencyPerDay,
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
      'color_hex': colorHex,
    };
  }
}
