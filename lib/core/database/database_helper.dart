import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../../data/datasources/builtin_words.dart';

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

          // الكلمات التي أضافها المستخدم يدويًا كانت تدخل المراجعة
          // تلقائيًا في الإصدار السابق، لذلك نحافظ على هذا السلوك.
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

    await _seedIfEmpty(_database!);
    return _database!;
  }

  Future<void> _seedIfEmpty(Database db) async {
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM words')) ??
            0;
    if (count != 0) return;

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final word in builtinWords) {
      batch.insert('words', {
        'german': word[0],
        'translation': word[1],
        'example': word[2],
        'builtin': 1,
        'created_at': now,
      });
    }

    await batch.commit(noResult: true);
  }
}
