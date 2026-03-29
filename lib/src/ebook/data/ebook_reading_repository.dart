import 'package:sqflite/sqflite.dart';

import 'ebook_reading_db.dart';

class EbookReadingStats {
  final Map<String, int> totalSecondsByBook;
  final int currentWeekSeconds;
  final int previousWeekSeconds;

  const EbookReadingStats({
    required this.totalSecondsByBook,
    required this.currentWeekSeconds,
    required this.previousWeekSeconds,
  });

  int get totalSecondsAllBooks => totalSecondsByBook.values.fold(0, (a, b) => a + b);
}

class EbookReadingRepository {
  final EbookReadingDB _db = EbookReadingDB.instance;

  Future<void> addReadingDuration({
    required String ebookId,
    required Duration duration,
    DateTime? endedAt,
  }) async {
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
      final chunk = remaining <= secondsInThisDay ? remaining : secondsInThisDay;
      final dayKey = _dayKey(cursor);

      await db.rawInsert(
        '''
        INSERT INTO ebook_reading_daily(ebook_id, day_key, seconds, updated_at)
        VALUES(?, ?, ?, ?)
        ON CONFLICT(ebook_id, day_key)
        DO UPDATE SET
          seconds = seconds + excluded.seconds,
          updated_at = excluded.updated_at
        ''',
        [ebookId, dayKey, chunk, DateTime.now().toIso8601String()],
      );

      remaining -= chunk;
      cursor = dayStart;
    }
  }

  Future<EbookReadingStats> fetchStats() async {
    final db = await _db.database;

    final totalRows = await db.rawQuery(
      'SELECT ebook_id, SUM(seconds) AS total_seconds FROM ebook_reading_daily GROUP BY ebook_id',
    );

    final totalSecondsByBook = <String, int>{};
    for (final row in totalRows) {
      final ebookId = (row['ebook_id'] ?? '').toString();
      if (ebookId.isEmpty) continue;
      totalSecondsByBook[ebookId] = (row['total_seconds'] as num?)?.toInt() ?? 0;
    }

    final now = DateTime.now();
    final currentWeekStart = _startOfWeek(now);
    final nextWeekStart = currentWeekStart.add(const Duration(days: 7));
    final prevWeekStart = currentWeekStart.subtract(const Duration(days: 7));

    final currentWeekSeconds = await _sumSecondsBetween(
      db,
      start: currentWeekStart,
      end: nextWeekStart,
    );

    final previousWeekSeconds = await _sumSecondsBetween(
      db,
      start: prevWeekStart,
      end: currentWeekStart,
    );

    return EbookReadingStats(
      totalSecondsByBook: totalSecondsByBook,
      currentWeekSeconds: currentWeekSeconds,
      previousWeekSeconds: previousWeekSeconds,
    );
  }

  Future<int> _sumSecondsBetween(
    Database db, {
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(seconds), 0) AS total_seconds
      FROM ebook_reading_daily
      WHERE day_key >= ? AND day_key < ?
      ''',
      [_dayKey(start), _dayKey(end)],
    );

    if (rows.isEmpty) return 0;
    return (rows.first['total_seconds'] as num?)?.toInt() ?? 0;
  }

  DateTime _startOfWeek(DateTime date) {
    final offset = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: offset));
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
