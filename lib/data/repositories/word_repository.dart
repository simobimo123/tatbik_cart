import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class WordRepository {
  WordRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<WordModel>> getWords([String query = '']) async {
    final db = await _databaseHelper.database;
    final q = query.trim();

    final rows = await db.rawQuery(
      'SELECT w.*, c.name AS category_name '
      'FROM words w '
      'LEFT JOIN categories c ON c.id=w.category_id '
      '${q.isEmpty
          ? 'ORDER BY w.german COLLATE NOCASE ASC '
          : 'WHERE w.german LIKE ? OR w.translation LIKE ? '
            'ORDER BY w.german COLLATE NOCASE ASC '}'
      'LIMIT 500',
      q.isEmpty ? <Object?>[] : <Object?>['%$q%', '%$q%'],
    );

    return rows.map(WordModel.fromMap).toList();
  }

  Future<int> count() async {
    final db = await _databaseHelper.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM words'),
        ) ??
        0;
  }

  Future<int> dueCount({int? categoryId, String? difficulty}) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    final filters = <String>['(r.due_at IS NULL OR r.due_at<=?)'];
    final args = <Object?>[now];
    if (categoryId != null) {
      filters.add('w.category_id=?');
      args.add(categoryId);
    }
    if (difficulty != null) {
      filters.add('w.difficulty=?');
      args.add(difficulty);
    }

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM words w '
            'INNER JOIN reviews r ON r.word_id=w.id '
            'WHERE ${filters.join(' AND ') }',
            args,
          ),
        ) ??
        0;
  }

  Future<List<WordModel>> dueWords({
    int limit = 300,
    int? categoryId,
    String? difficulty,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    final filters = <String>['(r.due_at IS NULL OR r.due_at<=?)'];
    final args = <Object?>[now];
    if (categoryId != null) {
      filters.add('w.category_id=?');
      args.add(categoryId);
    }
    if (difficulty != null) {
      filters.add('w.difficulty=?');
      args.add(difficulty);
    }
    args.add(limit);

    final rows = await db.rawQuery(
      'SELECT w.* '
      'FROM words w '
      'INNER JOIN reviews r ON r.word_id=w.id '
      'WHERE ${filters.join(' AND ') } '
      'ORDER BY COALESCE(r.due_at, "") ASC,w.id ASC '
      'LIMIT ?',
      args,
    );

    return rows.map(WordModel.fromMap).toList();
  }

  Future<void> addToReview({
    required String german,
    required String translation,
    required String example,
    required String exampleTranslation,
    String difficulty = 'unspecified',
    int? categoryId,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final wordId = await txn.insert('words', {
        'german': german.trim(),
        'translation': translation.trim(),
        'example': example.trim(),
        'example_translation': exampleTranslation.trim(),
        'difficulty': difficulty,
        'category_id': categoryId,
        'builtin': 0,
        'created_at': now,
      });

      await txn.insert('reviews', {
        'word_id': wordId,
        'interval_days': 0,
        'ease': 2.5,
        'repetitions': 0,
        'due_at': now,
      });
    });
  }

  Future<List<WordModel>> reviewWords() async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery(
      'SELECT w.*, c.name AS category_name '
      'FROM words w '
      'INNER JOIN reviews r ON r.word_id=w.id '
      'LEFT JOIN categories c ON c.id=w.category_id '
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
