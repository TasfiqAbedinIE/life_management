import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ebook_reading_db.dart';

class EbookReadingStats {
  final Map<String, int> totalSecondsByBook;
  final int currentWeekSeconds;
  final int previousWeekSeconds;
  final Map<DateTime, int> currentWeekDailySeconds;
  final int currentWeekBooksRead;
  final int readingStreakDays;

  const EbookReadingStats({
    required this.totalSecondsByBook,
    required this.currentWeekSeconds,
    required this.previousWeekSeconds,
    this.currentWeekDailySeconds = const {},
    this.currentWeekBooksRead = 0,
    this.readingStreakDays = 0,
  });

  int get totalSecondsAllBooks =>
      totalSecondsByBook.values.fold(0, (a, b) => a + b);
}

class EbookReadingRepository {
  final EbookReadingDB _db = EbookReadingDB.instance;

  static final StreamController<void> _statsChanges =
      StreamController<void>.broadcast();

  static Stream<void> get statsChanges => _statsChanges.stream;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> addReadingDuration({
    required String ebookId,
    required Duration duration,
    DateTime? endedAt,
  }) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return;

    final db = await _db.database;
    final end = endedAt ?? DateTime.now();
    var remaining = totalSeconds;
    var cursor = end;

    while (remaining > 0) {
      final dayStart = DateTime(cursor.year, cursor.month, cursor.day);
      final secondsInThisDay = cursor.difference(dayStart).inSeconds;
      if (secondsInThisDay <= 0) {
        cursor = cursor.subtract(const Duration(seconds: 1));
        continue;
      }
      final chunk = remaining <= secondsInThisDay
          ? remaining
          : secondsInThisDay;
      final dayKey = _dayKey(cursor);

      await db.rawInsert(
        '''
        INSERT INTO ebook_reading_daily(user_id, ebook_id, day_key, seconds, updated_at)
        VALUES(?, ?, ?, ?, ?)
        ON CONFLICT(user_id, ebook_id, day_key)
        DO UPDATE SET
          seconds = seconds + excluded.seconds,
          updated_at = excluded.updated_at
        ''',
        [userId, ebookId, dayKey, chunk, DateTime.now().toIso8601String()],
      );

      remaining -= chunk;
      cursor = dayStart;
    }

    _statsChanges.add(null);
  }

  Future<EbookReadingStats> fetchStats() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return const EbookReadingStats(
        totalSecondsByBook: {},
        currentWeekSeconds: 0,
        previousWeekSeconds: 0,
      );
    }

    final db = await _db.database;

    final totalRows = await db.rawQuery(
      '''
      SELECT ebook_id, SUM(seconds) AS total_seconds
      FROM ebook_reading_daily
      WHERE user_id = ?
      GROUP BY ebook_id
      ''',
      [userId],
    );

    final totalSecondsByBook = <String, int>{};
    for (final row in totalRows) {
      final ebookId = (row['ebook_id'] ?? '').toString();
      if (ebookId.isEmpty) continue;
      totalSecondsByBook[ebookId] =
          (row['total_seconds'] as num?)?.toInt() ?? 0;
    }

    final now = DateTime.now();
    final currentWeekStart = _startOfWeek(now);
    final nextWeekStart = currentWeekStart.add(const Duration(days: 7));
    final prevWeekStart = currentWeekStart.subtract(const Duration(days: 7));

    final currentWeekSeconds = await _sumSecondsBetween(
      db,
      userId: userId,
      start: currentWeekStart,
      end: nextWeekStart,
    );

    final previousWeekSeconds = await _sumSecondsBetween(
      db,
      userId: userId,
      start: prevWeekStart,
      end: currentWeekStart,
    );

    final currentWeekDailySeconds = await _dailySecondsBetween(
      db,
      userId: userId,
      start: currentWeekStart,
      end: nextWeekStart,
    );

    final currentWeekBooksRead = await _distinctBooksBetween(
      db,
      userId: userId,
      start: currentWeekStart,
      end: nextWeekStart,
    );

    final readingStreakDays = await _readingStreakDays(
      db,
      userId: userId,
      throughDate: DateTime.now(),
    );

    return EbookReadingStats(
      totalSecondsByBook: totalSecondsByBook,
      currentWeekSeconds: currentWeekSeconds,
      previousWeekSeconds: previousWeekSeconds,
      currentWeekDailySeconds: currentWeekDailySeconds,
      currentWeekBooksRead: currentWeekBooksRead,
      readingStreakDays: readingStreakDays,
    );
  }

  Future<int> _sumSecondsBetween(
    Database db, {
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(seconds), 0) AS total_seconds
      FROM ebook_reading_daily
      WHERE user_id = ? AND day_key >= ? AND day_key < ?
      ''',
      [userId, _dayKey(start), _dayKey(end)],
    );

    if (rows.isEmpty) return 0;
    return (rows.first['total_seconds'] as num?)?.toInt() ?? 0;
  }

  Future<Map<DateTime, int>> _dailySecondsBetween(
    Database db, {
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT day_key, COALESCE(SUM(seconds), 0) AS total_seconds
      FROM ebook_reading_daily
      WHERE user_id = ? AND day_key >= ? AND day_key < ?
      GROUP BY day_key
      ''',
      [userId, _dayKey(start), _dayKey(end)],
    );

    final dailySeconds = <DateTime, int>{};
    for (final row in rows) {
      final day = _parseDayKey((row['day_key'] ?? '').toString());
      if (day == null) continue;
      dailySeconds[day] = (row['total_seconds'] as num?)?.toInt() ?? 0;
    }
    return dailySeconds;
  }

  Future<int> _distinctBooksBetween(
    Database db, {
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT ebook_id) AS book_count
      FROM ebook_reading_daily
      WHERE user_id = ? AND day_key >= ? AND day_key < ? AND seconds > 0
      ''',
      [userId, _dayKey(start), _dayKey(end)],
    );

    if (rows.isEmpty) return 0;
    return (rows.first['book_count'] as num?)?.toInt() ?? 0;
  }

  Future<int> _readingStreakDays(
    Database db, {
    required String userId,
    required DateTime throughDate,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT day_key, COALESCE(SUM(seconds), 0) AS total_seconds
      FROM ebook_reading_daily
      WHERE user_id = ? AND day_key <= ?
      GROUP BY day_key
      HAVING total_seconds > 0
      ''',
      [userId, _dayKey(throughDate)],
    );

    final activeDays = <String>{};
    for (final row in rows) {
      activeDays.add((row['day_key'] ?? '').toString());
    }

    var cursor = DateTime(throughDate.year, throughDate.month, throughDate.day);
    var streak = 0;
    while (activeDays.contains(_dayKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _startOfWeek(DateTime date) {
    final offset = date.weekday - DateTime.monday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: offset));
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseDayKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}
