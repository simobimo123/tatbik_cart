import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../models/word_model.dart';

class DiscoveryRepository {
  DiscoveryRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<WordModel?> nextWord({
    int? categoryId,
    String? difficulty,
  }) async {
    final db = await _databaseHelper.database;

    final filters = <String>[
      'w.builtin=1',
      'r.word_id IS NULL',
      '(d.word_id IS NULL OR d.known=1)',
    ];
    final args = <Object?>[];

    if (categoryId != null) {
      filters.add('w.category_id=?');
      args.add(categoryId);
    }

    if (difficulty != null) {
      if (difficulty == 'unspecified') {
        filters.add("COALESCE(w.difficulty, 'unspecified')='unspecified'");
      } else {
        filters.add('w.difficulty=?');
        args.add(difficulty);
      }
    }

    final rows = await db.rawQuery(
      'SELECT w.* '
      'FROM words w '
      'LEFT JOIN word_discoveries d ON d.word_id=w.id '
      'LEFT JOIN reviews r ON r.word_id=w.id '
      'WHERE ' + filters.join(' AND ') + ' '
      'ORDER BY '
      'CASE WHEN d.word_id IS NULL THEN 0 ELSE 1 END ASC, '
      'CASE WHEN d.word_id IS NULL THEN w.id ELSE d.discovery_order END ASC, '
      'w.id ASC '
      'LIMIT 1',
      args,
    );

    if (rows.isEmpty) return null;
    return WordModel.fromMap(rows.first);
  }
  Future<int> newWordCount({
    int? categoryId,
    String? difficulty,
  }) async {
    final db = await _databaseHelper.database;

    final filters = <String>[
      'w.builtin=1',
      'd.word_id IS NULL',
    ];
    final args = <Object?>[];

    if (categoryId != null) {
      filters.add('w.category_id=?');
      args.add(categoryId);
    }

    if (difficulty != null) {
      if (difficulty == 'unspecified') {
        filters.add("COALESCE(w.difficulty, 'unspecified')='unspecified'");
      } else {
        filters.add('w.difficulty=?');
        args.add(difficulty);
      }
    }

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) '
            'FROM words w '
            'LEFT JOIN word_discoveries d ON d.word_id=w.id '
            'WHERE ' + filters.join(' AND '),
            args,
          ),
        ) ??
        0;
  }
  Future<int> availableCount({
    int? categoryId,
    String? difficulty,
  }) async {
    final db = await _databaseHelper.database;

    final filters = <String>[
      'w.builtin=1',
      'r.word_id IS NULL',
      '(d.word_id IS NULL OR d.known=1)',
    ];
    final args = <Object?>[];

    if (categoryId != null) {
      filters.add('w.category_id=?');
      args.add(categoryId);
    }

    if (difficulty != null) {
      if (difficulty == 'unspecified') {
        filters.add("COALESCE(w.difficulty, 'unspecified')='unspecified'");
      } else {
        filters.add('w.difficulty=?');
        args.add(difficulty);
      }
    }

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) '
            'FROM words w '
            'LEFT JOIN word_discoveries d ON d.word_id=w.id '
            'LEFT JOIN reviews r ON r.word_id=w.id '
            'WHERE ' + filters.join(' AND '),
            args,
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
