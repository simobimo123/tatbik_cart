import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';

class ReviewRepository {
  ReviewRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<void> review(int wordId, bool remembered) async {
    final db = await _databaseHelper.database;
    final old = await db.query(
      'reviews',
      where: 'word_id=?',
      whereArgs: [wordId],
      limit: 1,
    );

    final map = old.isEmpty ? null : old.first;
    final repetitions = map?['repetitions'] as int? ?? 0;
    final ease = (map?['ease'] as num?)?.toDouble() ?? 2.5;
    final nextRepetitions = remembered ? repetitions + 1 : 0;
    final previousInterval = map?['interval_days'] as int? ?? 30;

    final days = remembered
        ? (nextRepetitions == 1
            ? 1
            : nextRepetitions == 2
                ? 3
                : nextRepetitions == 3
                    ? 7
                    : nextRepetitions == 4
                        ? 14
                        : nextRepetitions == 5
                            ? 30
                            : (previousInterval * ease)
                                .round()
                                .clamp(30, 365)
                                .toInt())
        : 0;

    final nextEase = remembered
        ? (ease + 0.05).clamp(1.3, 3.0)
        : (ease - 0.15).clamp(1.3, 3.0);

    await db.insert(
      'reviews',
      {
        'word_id': wordId,
        'interval_days': days,
        'ease': nextEase,
        'repetitions': nextRepetitions,
        'due_at': DateTime.now()
            .add(
              remembered
                  ? Duration(days: days)
                  : Duration.zero,
            )
            .toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
