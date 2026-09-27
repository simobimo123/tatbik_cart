import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../../data/datasources/word_catalog.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final directory = await getDatabasesPath();
    _database = await openDatabase(
      path.join(directory, 'deutsch_lernen.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE word_discoveries ('
            'word_id INTEGER PRIMARY KEY, '
            'known INTEGER NOT NULL, '
            'discovered_at TEXT NOT NULL'
            ')',
          );
          await db.execute(
            'CREATE INDEX word_discoveries_known ON word_discoveries(known)',
          );

          // نحافظ على الكلمات اليدوية التي كانت تدخل المراجعة
          // تلقائيًا في الإصدار السابق.
          final now = DateTime.now().toIso8601String();
          await db.execute(
            'INSERT OR IGNORE INTO reviews '
            '(word_id, interval_days, ease, repetitions, due_at) '
            'SELECT id, 0, 2.5, 0, ? FROM words WHERE builtin = 0',
            [now],
          );
        }
      },
    );

    await _syncWordCatalog(_database!);
    return _database!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute(
      'CREATE TABLE words ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'german TEXT NOT NULL, '
      'translation TEXT NOT NULL, '
      'example TEXT NOT NULL, '
      'builtin INTEGER NOT NULL DEFAULT 0, '
      'created_at TEXT NOT NULL'
      ')',
    );
    await db.execute(
      'CREATE TABLE reviews ('
      'word_id INTEGER PRIMARY KEY, '
      'interval_days INTEGER NOT NULL DEFAULT 0, '
      'ease REAL NOT NULL DEFAULT 2.5, '
      'repetitions INTEGER NOT NULL DEFAULT 0, '
      'due_at TEXT'
      ')',
    );
    await db.execute(
      'CREATE TABLE word_discoveries ('
      'word_id INTEGER PRIMARY KEY, '
      'known INTEGER NOT NULL, '
      'discovered_at TEXT NOT NULL'
      ')',
    );
    await db.execute('CREATE INDEX words_german ON words(german)');
    await db.execute(
      'CREATE INDEX word_discoveries_known ON word_discoveries(known)',
    );
  }

  Future<void> _syncWordCatalog(Database db) async {
    final catalog = await WordCatalog.load();
    if (catalog.isEmpty) return;

    final batch = db.batch();

    for (final word in catalog) {
      batch.rawInsert(
        'INSERT INTO words (german, translation, example, builtin, created_at) '
        'SELECT ?, ?, ?, 1, ? '
        'WHERE NOT EXISTS ('
        'SELECT 1 FROM words WHERE german = ? AND builtin = 1'
        ')',
        [
          word.german,
          word.translation,
          word.example,
          DateTime.now().toIso8601String(),
          word.german,
        ],
      );
    }

    await batch.commit(noResult: true);
  }
}
