// This class will be a singleton to manage the local SQLite database.
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'notes_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY,
        etag TEXT,
        title TEXT,
        content TEXT,
        modified INTEGER,
        favorite INTEGER
      )
    ''');
  }

  // CRUD Operations for notes

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes');
    return List.generate(maps.length, (i) => Note.fromDbMap(maps[i]));
  }
  
  Future<Note?> getNoteById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Note.fromDbMap(maps.first);
    }
    return null;
  }

  Future<void> insertOrUpdateNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertOrUpdate(List<Note> notes) async {
    final db = await database;
    Batch batch = db.batch();
    for (var note in notes) {
      batch.insert('notes', note.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteNote(int id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('notes');
  }
}