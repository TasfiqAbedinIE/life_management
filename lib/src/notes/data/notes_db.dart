import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class NotesDB {
  NotesDB._();
  static final NotesDB instance = NotesDB._();

  static const _dbName = 'notes.db';
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
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            color_value INTEGER NOT NULL DEFAULT 4294965224,
            tags_csv TEXT NOT NULL DEFAULT '',
            note_type TEXT NOT NULL DEFAULT 'rich'
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_notes_updated_at ON notes(updated_at)',
        );
        await db.execute('CREATE INDEX idx_notes_pinned ON notes(is_pinned)');
        await db.execute('CREATE INDEX idx_notes_type ON notes(note_type)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE notes ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4294965224',
          );
          await db.execute(
            "ALTER TABLE notes ADD COLUMN tags_csv TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE notes ADD COLUMN note_type TEXT NOT NULL DEFAULT 'rich'",
          );
          await db.execute('CREATE INDEX idx_notes_type ON notes(note_type)');
        }
      },
    );
  }
}
