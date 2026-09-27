import 'package:sqflite/sqflite.dart';
import '../../core/config/learning_config.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class DiscoveryRepository {
  DiscoveryRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<WordModel?> nextWord() async {
    final db = await _databaseHelper.database;
    final step = await _currentStep(db);

    final rows = await db.rawQuery(
      'SELECT w.* '
      'FROM words w '
      'LEFT JOIN word_discoveries d ON d.word_id=w.id '
      'WHERE w.builtin=1 '
      'AND (d.word_id IS NULL OR (d.known=1 AND d.due_step<=?)) '
      'ORDER BY '
      'CASE WHEN d.known=1 THEN 0 ELSE 1 END, '
      'COALESCE(d.due_step,0) ASC, '
      'w.id ASC '
      'LIMIT 1',
      [step],
    );

    if (rows.isEmpty) return null;
    return WordModel.fromMap(rows.first);
  }

  Future<int> newWordCount() async {
    final db = await _databaseHelper.database;

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) '
            'FROM words w '
            'LEFT JOIN word_discoveries d ON d.word_id=w.id '
            'WHERE w.builtin=1 AND d.word_id IS NULL',
          ),
        ) ??
        0;
  }

  Future<int> availableCount() async {
    final db = await _databaseHelper.database;
    final step = await _currentStep(db);

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) '
            'FROM words w '
            'LEFT JOIN word_discoveries d ON d.word_id=w.id '
            'WHERE w.builtin=1 '
            'AND (d.word_id IS NULL OR (d.known=1 AND d.due_step<=?))',
            [step],
          ),
        ) ??
        0;
  }

  Future<int> currentStep() async {
    final db = await _databaseHelper.database;
    return _currentStep(db);
  }

  Future<void> answer(
    WordModel word, {
    required bool known,
  }) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      final current = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT value FROM app_state WHERE key=?',
              ['discovery_step'],
            ),
          ) ??
          0;

      final nextStep = current + 1;

      await txn.insert(
        'app_state',
        {'key': 'discovery_step', 'value': nextStep},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final oldRows = await txn.query(
        'word_discoveries',
        columns: ['times_seen'],
        where: 'word_id=?',
        whereArgs: [word.id],
        limit: 1,
      );

      final oldTimesSeen =
          oldRows.isEmpty ? 0 : oldRows.first['times_seen'] as int;
      final timesSeen = oldTimesSeen + 1;
      final now = DateTime.now().toIso8601String();

      if (known) {
        await txn.insert(
          'word_discoveries',
          {
            'word_id': word.id,
            'known': 1,
            'discovered_at': now,
            'due_step':
                nextStep + LearningConfig.discoveryKnownDelayCards,
            'times_seen': timesSeen,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await txn.insert(
          'word_discoveries',
          {
            'word_id': word.id,
            'known': 0,
            'discovered_at': now,
            'due_step': 0,
            'times_seen': timesSeen,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

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

  Future<int> _currentStep(Database db) async {
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT value FROM app_state WHERE key=?',
            ['discovery_step'],
          ),
        ) ??
        0;
  }
}
