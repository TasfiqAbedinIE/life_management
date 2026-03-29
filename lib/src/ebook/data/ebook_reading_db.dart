import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class EbookReadingDB {
  EbookReadingDB._();

  static final EbookReadingDB instance = EbookReadingDB._();

  static const _dbName = 'ebook_reading.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ebook_reading_daily(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ebook_id TEXT NOT NULL,
            day_key TEXT NOT NULL,
            seconds INTEGER NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(ebook_id, day_key)
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_ebook_reading_daily_day_key ON ebook_reading_daily(day_key)',
        );
        await db.execute(
          'CREATE INDEX idx_ebook_reading_daily_ebook_id ON ebook_reading_daily(ebook_id)',
        );
      },
    );
  }
}
