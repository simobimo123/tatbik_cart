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
      version: 5,
      onCreate: (db, version) => _createTables(db),
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

          final now = DateTime.now().toIso8601String();
          await db.execute(
            'INSERT OR IGNORE INTO reviews '
            '(word_id, interval_days, ease, repetitions, due_at) '
            'SELECT id, 0, 2.5, 0, ? FROM words WHERE builtin = 0',
            [now],
          );
        }

        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE words ADD COLUMN example_translation TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE word_discoveries ADD COLUMN due_step INTEGER NOT NULL DEFAULT 0",
          );
          await db.execute(
            "ALTER TABLE word_discoveries ADD COLUMN times_seen INTEGER NOT NULL DEFAULT 0",
          );
          await db.execute(
            'CREATE TABLE app_state ('
            'key TEXT PRIMARY KEY, '
            'value INTEGER NOT NULL'
            ')',
          );
          await db.insert(
            'app_state',
            {'key': 'discovery_step', 'value': 0},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS categories ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL UNIQUE, '
            'created_at TEXT NOT NULL'
            ')',
          );
          await db.execute(
            "ALTER TABLE words ADD COLUMN difficulty TEXT NOT NULL DEFAULT 'unspecified'",
          );
          await db.execute(
            'ALTER TABLE words ADD COLUMN category_id INTEGER',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS words_category ON words(category_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS words_difficulty ON words(difficulty)',
          );
        }

        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE word_discoveries ADD COLUMN discovery_order INTEGER NOT NULL DEFAULT 0",
          );
          await db.execute(
            'CREATE INDEX word_discoveries_queue '
            'ON word_discoveries(known, discovery_order)',
          );

          // ترتيب الكلمات المعروفة الموجودة سابقًا يحافظ على ترتيب اكتشافها.
          final knownRows = await db.query(
            'word_discoveries',
            columns: ['word_id'],
            where: 'known=1',
            orderBy: 'discovered_at ASC, word_id ASC',
          );

          var order = 0;
          for (final row in knownRows) {
            order++;
            await db.update(
              'word_discoveries',
              {'discovery_order': order},
              where: 'word_id=?',
              whereArgs: [row['word_id']],
            );
          }
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
      'example_translation TEXT NOT NULL DEFAULT "", '
      'difficulty TEXT NOT NULL DEFAULT "unspecified", '
      'category_id INTEGER, '
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
      'discovered_at TEXT NOT NULL, '
      'due_step INTEGER NOT NULL DEFAULT 0, '
      'times_seen INTEGER NOT NULL DEFAULT 0, '
      'discovery_order INTEGER NOT NULL DEFAULT 0'
      ')',
    );

    await db.execute(
      'CREATE TABLE categories ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL UNIQUE, '
      'created_at TEXT NOT NULL'
      ')',
    );

    await db.execute(
      'CREATE TABLE app_state ('
      'key TEXT PRIMARY KEY, '
      'value INTEGER NOT NULL'
      ')',
    );

    await db.execute('CREATE INDEX words_german ON words(german)');
    await db.execute(
      'CREATE INDEX word_discoveries_queue '
      'ON word_discoveries(known, discovery_order)',
    );
  }

  Future<void> _syncWordCatalog(Database db) async {
    final catalog = await WordCatalog.load();
    if (catalog.isEmpty) return;

    await db.transaction((txn) async {
      for (final item in catalog) {
        final existing = await txn.query(
          'words',
          columns: ['id'],
          where: 'german=? AND builtin=1',
          whereArgs: [item.german],
          limit: 1,
        );

        int? categoryId;
        if (item.category != null && item.category!.trim().isNotEmpty) {
          final name = item.category!.trim();
          final existingCategory = await txn.query(
            'categories',
            columns: ['id'],
            where: 'LOWER(name)=LOWER(?)',
            whereArgs: [name],
            limit: 1,
          );
          if (existingCategory.isNotEmpty) {
            categoryId = existingCategory.first['id'] as int;
          } else {
            categoryId = await txn.insert('categories', {
              'name': name,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        final values = {
          'german': item.german,
          'translation': item.translation,
          'example': item.example,
          'example_translation': item.exampleTranslation,
          'difficulty': item.difficulty,
          'category_id': categoryId,
          'builtin': 1,
          'created_at': DateTime.now().toIso8601String(),
        };

        if (existing.isEmpty) {
          await txn.insert('words', values);
        } else {
          await txn.update(
            'words',
            values,
            where: 'id=?',
            whereArgs: [existing.first['id']],
          );
        }
      }
    });
  }
}
