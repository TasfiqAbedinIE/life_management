import 'package:sqflite/sqflite.dart';
import 'notes_db.dart';
import '../models/note.dart';

class NotesRepository {
  NotesRepository._();
  static final NotesRepository instance = NotesRepository._();

  Future<int> insertNote(Note note) async {
    final db = await NotesDB.instance.database;
    return db.insert(
      'notes',
      note.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateNote(Note note) async {
    if (note.id == null) {
      throw ArgumentError('Note id is null. Cannot update.');
    }

    final db = await NotesDB.instance.database;
    return db.update(
      'notes',
      note.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await NotesDB.instance.database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<Note?> getNoteById(int id) async {
    final db = await NotesDB.instance.database;
    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  /// Pinned first, then most recently updated
  Future<List<Note>> fetchAllNotes() async {
    final db = await NotesDB.instance.database;
    final rows = await db.query(
      'notes',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    return rows.map(Note.fromMap).toList();
  }

  Future<int> setPinned({required int id, required bool pinned}) async {
    final db = await NotesDB.instance.database;
    return db.update(
      'notes',
      {
        'is_pinned': pinned ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
