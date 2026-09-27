import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class DiscoveryRepository {
  DiscoveryRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<WordModel?> nextWord() async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery(
      'SELECT w.* '
      'FROM words w '
      'LEFT JOIN word_discoveries d ON d.word_id=w.id '
      'WHERE w.builtin=1 '
      'AND (d.word_id IS NULL OR d.known=1) '
      'ORDER BY '
      'CASE WHEN d.word_id IS NULL THEN 0 ELSE 1 END ASC, '
      'CASE WHEN d.word_id IS NULL THEN w.id ELSE d.discovery_order END ASC, '
      'w.id ASC '
      'LIMIT 1',
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

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) '
            'FROM words w '
            'LEFT JOIN word_discoveries d ON d.word_id=w.id '
            'WHERE w.builtin=1 '
            'AND (d.word_id IS NULL OR d.known=1)',
          ),
        ) ??
        0;
  }

  Future<void> answer(
    WordModel word, {
    required bool known,
  }) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
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

      if (!known) {
        await txn.insert(
          'word_discoveries',
          {
            'word_id': word.id,
            'known': 0,
            'discovered_at': now,
            'due_step': 0,
            'times_seen': timesSeen,
            'discovery_order': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // الكلمة غير المعروفة تدخل المراجعة مباشرة.
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

        return;
      }

      // أعرفها = انقلها إلى آخر طابور الاكتشاف الحالي.
      // كل الكلمات الجديدة/غير المكتشفة تبقى قبلها.
      final maxOrder = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COALESCE(MAX(discovery_order), 0) '
              'FROM word_discoveries WHERE known=1',
            ),
          ) ??
          0;

      await txn.insert(
        'word_discoveries',
        {
          'word_id': word.id,
          'known': 1,
          'discovered_at': now,
          'due_step': 0,
          'times_seen': timesSeen,
          'discovery_order': maxOrder + 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}
