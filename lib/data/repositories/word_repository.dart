import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class WordRepository {
  WordRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  String _wordKey(String german) => german.trim().toLowerCase();

  Future<List<WordModel>> getWords([String query = '']) async {
    final db = await _databaseHelper.database;
    final q = query.trim();

    final rows = await db.rawQuery(
      'SELECT w.*, c.name AS category_name, '
      'c.difficulty AS category_difficulty '
      'FROM words w '
      'LEFT JOIN categories c ON c.id=w.category_id '
      '${q.isEmpty
          ? 'ORDER BY w.german COLLATE NOCASE ASC, w.id ASC '
          : 'WHERE w.german LIKE ? OR w.translation LIKE ? '
            'ORDER BY w.german COLLATE NOCASE ASC, w.id ASC '}'
      'LIMIT 500',
      q.isEmpty ? <Object?>[] : <Object?>['%$q%', '%$q%'],
    );

    final unique = <String, WordModel>{};
    for (final row in rows.map(WordModel.fromMap)) {
      unique.putIfAbsent(_wordKey(row.german), () => row);
    }

    return unique.values.toList();
  }

  Future<int> count() async {
    final db = await _databaseHelper.database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT LOWER(TRIM(german))) FROM words',
          ),
        ) ??
        0;
  }

  Future<int> dueCount() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT LOWER(TRIM(w.german))) '
            'FROM words w '
            'INNER JOIN reviews r ON r.word_id=w.id '
            'WHERE (r.due_at IS NULL OR r.due_at<=?)',
            [now],
          ),
        ) ??
        0;
  }

  Future<List<WordModel>> dueWords({
    int limit = 300,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    final rows = await db.rawQuery(
      'SELECT w.* '
      'FROM words w '
      'INNER JOIN reviews r ON r.word_id=w.id '
      'WHERE (r.due_at IS NULL OR r.due_at<=?) '
      'AND w.id = ('
      '  SELECT MIN(w2.id) '
      '  FROM words w2 '
      '  INNER JOIN reviews r2 ON r2.word_id=w2.id '
      '  WHERE (r2.due_at IS NULL OR r2.due_at<=?) '
      '    AND LOWER(TRIM(w2.german))=LOWER(TRIM(w.german))'
      ') '
      'ORDER BY COALESCE(r.due_at, ""),w.id ASC '
      'LIMIT ?',
      [now, now, limit],
    );

    return rows.map(WordModel.fromMap).toList();
  }


  Future<void> addToReview({
    required String german,
    required String translation,
    required String example,
    required String exampleTranslation,
    String difficulty = 'unspecified',
  }) async {
    final db = await _databaseHelper.database;
    final cleanGerman = german.trim();
    final cleanTranslation = translation.trim();
    final cleanExample = example.trim();
    final cleanExampleTranslation = exampleTranslation.trim();
    final now = DateTime.now().toIso8601String();

    if (cleanGerman.isEmpty ||
        cleanTranslation.isEmpty ||
        cleanExample.isEmpty) {
      throw const FormatException('بيانات الكلمة غير مكتملة.');
    }

    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'words',
        columns: ['id'],
        where: 'LOWER(TRIM(german))=LOWER(TRIM(?))',
        whereArgs: [cleanGerman],
        limit: 1,
      );

      final int wordId;

      if (existingRows.isNotEmpty) {
        // الكلمة موجودة أصلًا: لا تنشئ نسخة ثانية منها.
        wordId = existingRows.first['id'] as int;
      } else {
        wordId = await txn.insert('words', {
          'german': cleanGerman,
          'translation': cleanTranslation,
          'example': cleanExample,
          'example_translation': cleanExampleTranslation,
          'difficulty': difficulty,
          'category_id': null,
          'builtin': 0,
          'created_at': now,
        });
      }

      final reviewExists = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM reviews WHERE word_id=?',
              [wordId],
            ),
          ) ??
          0;

      if (reviewExists == 0) {
        await txn.insert('reviews', {
          'word_id': wordId,
          'interval_days': 0,
          'ease': 2.5,
          'repetitions': 0,
          'due_at': now,
        });
      }
    });
  }

  Future<List<WordModel>> reviewWords() async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery(
      'SELECT w.*, c.name AS category_name, '
      'c.difficulty AS category_difficulty '
      'FROM words w '
      'INNER JOIN reviews r ON r.word_id=w.id '
      'LEFT JOIN categories c ON c.id=w.category_id '
      'WHERE w.id = ('
      '  SELECT MIN(w2.id) '
      '  FROM words w2 '
      '  INNER JOIN reviews r2 ON r2.word_id=w2.id '
      '  WHERE LOWER(TRIM(w2.german))=LOWER(TRIM(w.german))'
      ') '
      'ORDER BY w.german COLLATE NOCASE ASC,w.id ASC',
    );

    return rows.map(WordModel.fromMap).toList();
  }

  Future<void> remove(int id) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      await txn.delete(
        'reviews',
        where: 'word_id=?',
        whereArgs: [id],
      );
      await txn.delete(
        'word_discoveries',
        where: 'word_id=?',
        whereArgs: [id],
      );
      await txn.delete(
        'words',
        where: 'id=?',
        whereArgs: [id],
      );
    });
  }
}
