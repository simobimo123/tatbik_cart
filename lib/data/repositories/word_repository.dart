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

  Future<int> dueCount() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM words w '
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
      'ORDER BY COALESCE(r.due_at, ""),w.id ASC '
      'LIMIT ?',
      [now, limit],
    );

    return rows.map(WordModel.fromMap).toList();
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
