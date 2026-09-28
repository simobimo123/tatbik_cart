import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class WordExportRepository {
  WordExportRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<WordModel>> _queryWords({required bool reviewOnly}) async {
    final db = await _databaseHelper.database;

    final rows = reviewOnly
        ? await db.rawQuery(
            'SELECT w.*, c.name AS category_name, '
            'c.difficulty AS category_difficulty '
            'FROM words w '
            'INNER JOIN reviews r ON r.word_id=w.id '
            'LEFT JOIN categories c ON c.id=w.category_id '
            'ORDER BY w.german COLLATE NOCASE ASC,w.id ASC',
          )
        : await db.rawQuery(
            'SELECT w.*, c.name AS category_name, '
            'c.difficulty AS category_difficulty '
            'FROM words w '
            'LEFT JOIN categories c ON c.id=w.category_id '
            'ORDER BY w.german COLLATE NOCASE ASC,w.id ASC',
          );

    return rows.map(WordModel.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> _queryCategories() async {
    final db = await _databaseHelper.database;

    return db.query(
      'categories',
      columns: ['name', 'difficulty'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  Future<String> buildJson({required bool reviewOnly}) async {
    final words = await _queryWords(reviewOnly: reviewOnly);
    final categories = await _queryCategories();

    final payload = {
      'version': 3,
      'language': 'de',
      'type': reviewOnly ? 'review_words' : 'all_words',
      'exported_at': DateTime.now().toIso8601String(),
      'count': words.length,
      'categories': categories
          .map(
            (category) => {
              'name': category['name'],
              'difficulty':
                  (category['difficulty'] as String?)?.trim().isNotEmpty == true
                      ? category['difficulty']
                      : 'unspecified',
            },
          )
          .toList(),
      'words': words
          .map(
            (word) => {
              'german': word.german,
              'translation': word.translation,
              'example': word.example,
              'example_translation': word.exampleTranslation,
              'difficulty': word.difficulty,
              if (word.categoryName != null &&
                  word.categoryName!.isNotEmpty) ...{
                'category': word.categoryName,
                'category_difficulty': word.categoryDifficulty,
              },
            },
          )
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
