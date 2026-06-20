import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class EbookReadingDB {
  EbookReadingDB._();

  static final EbookReadingDB instance = EbookReadingDB._();

  static const _dbName = 'ebook_reading.db';
  static const _dbVersion = 2;

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
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE ebook_reading_daily_v2(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              ebook_id TEXT NOT NULL,
              day_key TEXT NOT NULL,
              seconds INTEGER NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE(user_id, ebook_id, day_key)
            )
          ''');

          await db.execute('''
            INSERT INTO ebook_reading_daily_v2(id, user_id, ebook_id, day_key, seconds, updated_at)
            SELECT id, '', ebook_id, day_key, seconds, updated_at
            FROM ebook_reading_daily
          ''');

          await db.execute('DROP TABLE ebook_reading_daily');
          await db.execute(
            'ALTER TABLE ebook_reading_daily_v2 RENAME TO ebook_reading_daily',
          );

          await db.execute(
            'CREATE INDEX idx_ebook_reading_daily_user_id ON ebook_reading_daily(user_id)',
          );
          await db.execute(
            'CREATE INDEX idx_ebook_reading_daily_day_key ON ebook_reading_daily(day_key)',
          );
          await db.execute(
            'CREATE INDEX idx_ebook_reading_daily_ebook_id ON ebook_reading_daily(ebook_id)',
          );
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ebook_reading_daily(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        ebook_id TEXT NOT NULL,
        day_key TEXT NOT NULL,
        seconds INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, ebook_id, day_key)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_ebook_reading_daily_user_id ON ebook_reading_daily(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_ebook_reading_daily_day_key ON ebook_reading_daily(day_key)',
    );
    await db.execute(
      'CREATE INDEX idx_ebook_reading_daily_ebook_id ON ebook_reading_daily(ebook_id)',
    );
  }
}
