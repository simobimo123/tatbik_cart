import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class DiscoveryRepository {
  DiscoveryRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<WordModel>> getPendingWords({int limit = 1}) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT w.* '
      'FROM words w '
      'LEFT JOIN word_discoveries d ON d.word_id = w.id '
      'WHERE w.builtin = 1 AND d.word_id IS NULL '
      'ORDER BY RANDOM() '
      'LIMIT ?',
      [limit],
    );

    return rows.map(WordModel.fromMap).toList();
  }

  Future<int> pendingCount() async {
    final db = await _databaseHelper.database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) '
            'FROM words w '
            'LEFT JOIN word_discoveries d ON d.word_id = w.id '
            'WHERE w.builtin = 1 AND d.word_id IS NULL',
          ),
        ) ??
        0;
  }

  Future<void> answer(WordModel word, {required bool known}) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(
        'word_discoveries',
        {
          'word_id': word.id,
          'known': known ? 1 : 0,
          'discovered_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!known) {
        // الكلمة غير المعروفة تدخل المراجعة فورًا.
        await txn.insert(
          'reviews',
          {
            'word_id': word.id,
            'interval_days': 0,
            'ease': 2.5,
            'repetitions': 0,
            'due_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}
