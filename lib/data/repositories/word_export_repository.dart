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
            'SELECT w.* '
            'FROM words w INNER JOIN reviews r ON r.word_id=w.id '
            'ORDER BY w.german COLLATE NOCASE ASC,w.id ASC',
          )
        : await db.query(
            'words',
            orderBy: 'german COLLATE NOCASE ASC,id ASC',
          );

    return rows.map(WordModel.fromMap).toList();
  }

  Future<String> buildJson({required bool reviewOnly}) async {
    final words = await _queryWords(reviewOnly: reviewOnly);

    final payload = {
      'version': 1,
      'language': 'de',
      'type': reviewOnly ? 'review_words' : 'all_words',
      'exported_at': DateTime.now().toIso8601String(),
      'count': words.length,
      'words': words
          .map(
            (word) => {
              'german': word.german,
              'translation': word.translation,
              'example': word.example,
              'example_translation': word.exampleTranslation,
            },
          )
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
