import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class NotesDB {
  NotesDB._();
  static final NotesDB instance = NotesDB._();

  static const _dbName = 'notes.db';
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
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Index for faster sorting/filtering later
        await db.execute(
          'CREATE INDEX idx_notes_updated_at ON notes(updated_at)',
        );
        await db.execute('CREATE INDEX idx_notes_pinned ON notes(is_pinned)');
      },
    );
  }
}
