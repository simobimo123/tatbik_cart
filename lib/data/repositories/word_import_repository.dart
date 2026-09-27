import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';

enum WordImportTarget { discovery, review }

class WordImportResult {
  const WordImportResult({required this.total, required this.added, required this.skipped});
  final int total;
  final int added;
  final int skipped;
}

class WordImportRepository {
  WordImportRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  String _normalizeDifficulty(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'easy':
      case 'سهل':
        return 'easy';
      case 'medium':
      case 'متوسط':
        return 'medium';
      case 'hard':
      case 'صعب':
        return 'hard';
      default:
        return 'unspecified';
    }
  }

  Future<WordImportResult> importJson(String content, {required WordImportTarget target}) async {
    final decoded = jsonDecode(content);
    final dynamic rawWords = decoded is List ? decoded : decoded is Map ? decoded['words'] : null;

    if (rawWords is! List) {
      throw const FormatException('صيغة JSON غير صحيحة: يجب أن يحتوي الملف على words.');
    }

    final items = <Map<String, String>>[];
    for (final raw in rawWords) {
      if (raw is! Map) continue;
      final german = raw['german']?.toString().trim() ?? '';
      final translation = raw['translation']?.toString().trim() ?? '';
      final example = raw['example']?.toString().trim() ?? '';
      final exampleTranslation = raw['example_translation']?.toString().trim() ?? '';
      final difficulty = _normalizeDifficulty(raw['difficulty']?.toString());
      final category = raw['category']?.toString().trim() ?? '';
      if (german.isEmpty || translation.isEmpty || example.isEmpty) continue;
      items.add({
        'german': german,
        'translation': translation,
        'example': example,
        'example_translation': exampleTranslation,
        'difficulty': difficulty,
        'category': category,
      });
    }

    if (items.isEmpty) {
      return const WordImportResult(total: 0, added: 0, skipped: 0);
    }

    final db = await _databaseHelper.database;
    final existingRows = await db.query('words', columns: ['id', 'german']);
    final idsByGerman = <String, int>{};
    for (final row in existingRows) {
      final german = (row['german'] as String).trim().toLowerCase();
      if (german.isNotEmpty && !idsByGerman.containsKey(german)) {
        idsByGerman[german] = row['id'] as int;
      }
    }

    var added = 0;
    var skipped = rawWords.length - items.length;
    final importedKeys = <String>{};

    await db.transaction((txn) async {
      for (final item in items) {
        final key = item['german']!.toLowerCase();
        int? categoryId;
        final categoryName = item['category']?.trim() ?? '';
        if (categoryName.isNotEmpty) {
          final categoryRows = await txn.query(
            'categories',
            columns: ['id'],
            where: 'LOWER(name)=LOWER(?)',
            whereArgs: [categoryName],
            limit: 1,
          );
          if (categoryRows.isNotEmpty) {
            categoryId = categoryRows.first['id'] as int;
          } else {
            categoryId = await txn.insert('categories', {
              'name': categoryName,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
        if (!importedKeys.add(key)) {
          skipped++;
          continue;
        }

        final existingId = idsByGerman[key];

        if (target == WordImportTarget.discovery) {
          if (existingId != null) {
            final reviewExists = Sqflite.firstIntValue(
                  await txn.rawQuery('SELECT COUNT(*) FROM reviews WHERE word_id=?', [existingId]),
                ) ?? 0;
            final discoveryExists = Sqflite.firstIntValue(
                  await txn.rawQuery('SELECT COUNT(*) FROM word_discoveries WHERE word_id=?', [existingId]),
                ) ?? 0;

            if (reviewExists > 0 || discoveryExists > 0) {
              skipped++;
              continue;
            }

            await txn.update(
              'words',
              {
                'german': item['german'],
                'translation': item['translation'],
                'example': item['example'],
                'example_translation': item['example_translation'],
                'difficulty': item['difficulty'],
                'category_id': categoryId,
                'builtin': 1,
              },
              where: 'id=?',
              whereArgs: [existingId],
            );
            added++;
            continue;
          }

          final id = await txn.insert('words', {
            'german': item['german'],
            'translation': item['translation'],
            'example': item['example'],
            'example_translation': item['example_translation'],
            'difficulty': item['difficulty'],
            'category_id': categoryId,
            'builtin': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
          idsByGerman[key] = id;
          added++;
          continue;
        }

        if (existingId != null) {
          final reviewExists = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM reviews WHERE word_id=?', [existingId]),
              ) ?? 0;
          if (reviewExists > 0) {
            skipped++;
            continue;
          }

          await txn.update(
            'words',
            {
              'translation': item['translation'],
              'example': item['example'],
              'example_translation': item['example_translation'],
              'difficulty': item['difficulty'],
              'category_id': categoryId,
            },
            where: 'id=?',
            whereArgs: [existingId],
          );
          await txn.insert(
            'reviews',
            {
              'word_id': existingId,
              'interval_days': 0,
              'ease': 2.5,
              'repetitions': 0,
              'due_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          added++;
          continue;
        }

        final id = await txn.insert('words', {
          'german': item['german'],
          'translation': item['translation'],
          'example': item['example'],
          'example_translation': item['example_translation'],
          'difficulty': item['difficulty'],
          'category_id': categoryId,
          'builtin': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
        await txn.insert('reviews', {
          'word_id': id,
          'interval_days': 0,
          'ease': 2.5,
          'repetitions': 0,
          'due_at': DateTime.now().toIso8601String(),
        });
        idsByGerman[key] = id;
        added++;
      }
    });

    return WordImportResult(total: items.length, added: added, skipped: skipped);
  }
}