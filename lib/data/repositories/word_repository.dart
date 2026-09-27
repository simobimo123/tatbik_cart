import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class WordRepository {
  WordRepository({DatabaseHelper? databaseHelper}) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;
  final DatabaseHelper _databaseHelper;

  Future<List<WordModel>> getWords([String query = '']) async {
    final db = await _databaseHelper.database;
    final q = query.trim();
    final rows = await db.query(
      'words',
      where: q.isEmpty ? null : 'german LIKE ? OR translation LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
      orderBy: 'german COLLATE NOCASE ASC',
      limit: 500,
    );
    return rows.map(WordModel.fromMap).toList();
  }

  Future<int> count() async {
    final db = await _databaseHelper.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM words')) ?? 0;
  }

  Future<int> dueCount() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM words w '
            'INNER JOIN reviews r ON r.word_id=w.id '
            'WHERE r.due_at IS NULL OR r.due_at<=?',
            [now],
          ),
        ) ??
        0;
  }

  Future<List<WordModel>> dueWords() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.rawQuery(
      'SELECT w.* FROM words w '
      'INNER JOIN reviews r ON r.word_id=w.id '
      'WHERE r.due_at IS NULL OR r.due_at<=? '
      'ORDER BY COALESCE(r.due_at, "") ASC,w.id ASC LIMIT 100',
      [now],
    );
    return rows.map(WordModel.fromMap).toList();
  }

  Future<void> add({
    required String german,
    required String translation,
    required String example,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final wordId = await txn.insert('words', {
        'german': german.trim(),
        'translation': translation.trim(),
        'example': example.trim(),
        'builtin': 0,
        'created_at': now,
      });

      // الكلمات التي يضيفها المستخدم يدويًا تدخل المراجعة مباشرة.
      await txn.insert('reviews', {
        'word_id': wordId,
        'interval_days': 0,
        'ease': 2.5,
        'repetitions': 0,
        'due_at': now,
      });
    });
  }

  Future<void> remove(int id) async {
    final db = await _databaseHelper.database;
    await db.delete('reviews', where: 'word_id=?', whereArgs: [id]);
    await db.delete('words', where: 'id=?', whereArgs: [id]);
  }
}
