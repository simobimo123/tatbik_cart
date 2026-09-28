import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../../data/datasources/word_catalog.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final instance = DatabaseHelper._();

  Database? _database;
  Future<Database>? _databaseFuture;

  Future<Database> get database {
    final existing = _databaseFuture;
    if (existing != null) return existing;

    final future = _openDatabase();
    _databaseFuture = future;
    return future;
  }

  Future<Database> _openDatabase() async {
    final directory = await getDatabasesPath();

    _database = await openDatabase(
      path.join(directory, 'deutsch_lernen.db'),
      version: 8,
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
        if (oldVersion < 6) {
          final categoryColumns = await db.rawQuery(
            'PRAGMA table_info(categories)',
          );
          final hasCategoryDifficulty = categoryColumns.any(
            (column) => column['name'] == 'difficulty',
          );

          if (!hasCategoryDifficulty) {
            await db.execute(
              "ALTER TABLE categories ADD COLUMN difficulty TEXT NOT NULL DEFAULT 'unspecified'",
            );
          }

          await db.execute(
            'CREATE INDEX IF NOT EXISTS categories_difficulty ON categories(difficulty)',
          );
        }

        if (oldVersion < 8) {
          await _deduplicateWords(db);

          // من الآن فصاعدًا لا يمكن إدخال نفس الكلمة مرتين
          // حتى لو اختلفت حالة الأحرف أو وُجدت مسافات زائدة.
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS words_german_unique '
            'ON words(LOWER(TRIM(german)))',
          );
        }

      },
    );

    // مزامنة كتالوج الكلمات مرة واحدة عند تهيئة قاعدة البيانات.
    // الاستعلامات اللاحقة (المراجعة، الاكتشاف، الإحصاءات...) لا تعيد
    // قراءة JSON ولا تمر على آلاف الكلمات في كل مرة.
    await _syncWordCatalog(_database!);
    return _database!;
  }

  Future<void> _deduplicateWords(Database db) async {
    // الإصدارات السابقة كانت تسمح بوجود أكثر من سجل لنفس
    // الكلمة بسبب اختلاف حالة الأحرف أو المسافات. نوحّدها
    // قبل إنشاء القيد الفريد، مع الحفاظ على حالة المراجعة
    // والاكتشاف الموجودة.
    final duplicateKeys = await db.rawQuery(
      'SELECT LOWER(TRIM(german)) AS word_key '
      'FROM words '
      'GROUP BY LOWER(TRIM(german)) '
      'HAVING COUNT(*)>1',
    );

    for (final duplicate in duplicateKeys) {
      final key = duplicate['word_key'] as String;

      final rows = await db.query(
        'words',
        columns: [
          'id',
          'german',
          'translation',
          'example',
          'example_translation',
          'difficulty',
          'category_id',
          'builtin',
          'created_at',
        ],
        where: 'LOWER(TRIM(german))=?',
        whereArgs: [key],
        orderBy: 'builtin DESC, id ASC',
      );

      if (rows.length < 2) continue;

      final keeper = rows.first;
      final keeperId = keeper['id'] as int;
      final duplicateIds =
          rows.skip(1).map((row) => row['id'] as int).toList();

      var mergedDifficulty =
          (keeper['difficulty'] as String?) ?? 'unspecified';
      var mergedCategoryId = keeper['category_id'] as int?;
      var mergedBuiltin = (keeper['builtin'] as int?) ?? 0;

      for (final row in rows.skip(1)) {
        if (mergedDifficulty == 'unspecified' &&
            row['difficulty'] != null &&
            row['difficulty'] != 'unspecified') {
          mergedDifficulty = row['difficulty'] as String;
        }
        mergedCategoryId ??= row['category_id'] as int?;
        if ((row['builtin'] as int? ?? 0) == 1) {
          mergedBuiltin = 1;
        }
      }

      await db.update(
        'words',
        {
          'difficulty': mergedDifficulty,
          'category_id': mergedCategoryId,
          'builtin': mergedBuiltin,
        },
        where: 'id=?',
        whereArgs: [keeperId],
      );

      final reviewPlaceholders =
          List.filled(duplicateIds.length + 1, '?').join(',');
      final allReviewRows = await db.rawQuery(
        'SELECT word_id, interval_days, ease, repetitions, due_at '
        'FROM reviews '
        'WHERE word_id IN ($reviewPlaceholders) '
        'ORDER BY repetitions DESC, interval_days DESC, '
        'COALESCE(due_at, "") ASC, word_id ASC',
        [keeperId, ...duplicateIds],
      );

      if (allReviewRows.isNotEmpty) {
        final bestReview = allReviewRows.first;
        await db.insert(
          'reviews',
          {
            'word_id': keeperId,
            'interval_days': bestReview['interval_days'],
            'ease': bestReview['ease'],
            'repetitions': bestReview['repetitions'],
            'due_at': bestReview['due_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final discoveryPlaceholders =
          List.filled(duplicateIds.length + 1, '?').join(',');
      final allDiscoveryRows = await db.rawQuery(
        'SELECT word_id, known, discovered_at, due_step, '
        'times_seen, discovery_order '
        'FROM word_discoveries '
        'WHERE word_id IN ($discoveryPlaceholders) '
        'ORDER BY known ASC, times_seen DESC, discovery_order ASC, word_id ASC',
        [keeperId, ...duplicateIds],
      );

      if (allDiscoveryRows.isNotEmpty) {
        final bestDiscovery = allDiscoveryRows.first;
        await db.insert(
          'word_discoveries',
          {
            'word_id': keeperId,
            'known': bestDiscovery['known'],
            'discovered_at': bestDiscovery['discovered_at'],
            'due_step': bestDiscovery['due_step'],
            'times_seen': bestDiscovery['times_seen'],
            'discovery_order': bestDiscovery['discovery_order'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final id in duplicateIds) {
        await db.delete(
          'reviews',
          where: 'word_id=?',
          whereArgs: [id],
        );
        await db.delete(
          'word_discoveries',
          where: 'word_id=?',
          whereArgs: [id],
        );
        await db.delete(
          'words',
          where: 'id=?',
          whereArgs: [id],
        );
      }
    }
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
      'difficulty TEXT NOT NULL DEFAULT "unspecified", '
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
      'CREATE UNIQUE INDEX words_german_unique '
      'ON words(LOWER(TRIM(german)))',
    );
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
          columns: ['id', 'builtin'],
          where: 'LOWER(TRIM(german))=LOWER(TRIM(?))',
          whereArgs: [item.german],
          orderBy: 'builtin DESC, id ASC',
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
              'difficulty': item.categoryDifficulty,
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
        } else if ((existing.first['builtin'] as int? ?? 0) == 1) {
          await txn.update(
            'words',
            values,
            where: 'id=?',
            whereArgs: [existing.first['id']],
          );
        } else {
          // لا ننشئ نسخة من كلمة يملكها المستخدم أصلًا.
          // إذا كانت الكلمة مرتبطة بالمراجعة أو الاكتشاف، نحافظ
          // على سجل المستخدم كما هو.
          final existingId = existing.first['id'] as int;
          final hasReview = Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COUNT(*) FROM reviews WHERE word_id=?',
                  [existingId],
                ),
              ) ??
              0;
          final hasDiscovery = Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COUNT(*) FROM word_discoveries WHERE word_id=?',
                  [existingId],
                ),
              ) ??
              0;

          if (hasReview == 0 && hasDiscovery == 0) {
            await txn.update(
              'words',
              values,
              where: 'id=?',
              whereArgs: [existingId],
            );
          }
        }
      }
    });
  }
}
