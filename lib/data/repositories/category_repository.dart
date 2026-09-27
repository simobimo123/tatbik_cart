import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  CategoryRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<CategoryModel>> getCategories() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT c.id, c.name, c.created_at, COUNT(w.id) AS word_count '
      'FROM categories c '
      'LEFT JOIN (words w INNER JOIN reviews r ON r.word_id=w.id) '
      'ON w.category_id=c.id '
      'GROUP BY c.id '
      'ORDER BY c.name COLLATE NOCASE ASC, c.id ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<int> create(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const FormatException('اسم التصنيف لا يمكن أن يكون فارغًا.');
    }

    final db = await _databaseHelper.database;
    final existing = await db.query(
      'categories',
      columns: ['id'],
      where: 'LOWER(name)=LOWER(?)',
      whereArgs: [clean],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    return db.insert('categories', {
      'name': clean,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> delete(int id) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'words',
        {'category_id': null},
        where: 'category_id=?',
        whereArgs: [id],
      );
      await txn.delete(
        'categories',
        where: 'id=?',
        whereArgs: [id],
      );
    });
  }

  Future<Map<String, int>> reviewDifficultyCounts() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT w.difficulty, COUNT(*) AS word_count '
      'FROM words w INNER JOIN reviews r ON r.word_id=w.id '
      'GROUP BY w.difficulty',
    );

    final result = <String, int>{
      'easy': 0,
      'medium': 0,
      'hard': 0,
      'unspecified': 0,
    };
    for (final row in rows) {
      final key = (row['difficulty'] as String?) ?? 'unspecified';
      result[key] = (row['word_count'] as int?) ?? 0;
    }
    return result;
  }

  Future<int> reviewCount() async {
    final db = await _databaseHelper.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM reviews'),
        ) ??
        0;
  }
}
