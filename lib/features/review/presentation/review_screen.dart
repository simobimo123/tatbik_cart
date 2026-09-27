import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/word_repository.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _words = WordRepository();
  final _reviews = ReviewRepository();
  List<WordModel> _queue = [];
  int _index = 0;
  bool _revealed = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final queue = await _words.dueWords();
    if (mounted) setState(() => _queue = queue);
  }

  Future<void> _answer(bool remembered) async {
    await _reviews.review(_queue[_index].id, remembered);
    if (mounted) setState(() { _index++; _revealed = false; });
  }

  Future<void> _delete() async {
    await _words.remove(_queue[_index].id);
    _queue.removeAt(_index);
    if (_index >= _queue.length) _index = _queue.length - 1;
    if (mounted) setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty || _index < 0 || _index >= _queue.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('المراجعة')),
        body: const Center(child: Text('لا توجد كلمات مستحقة للمراجعة الآن.')),
      );
    }
    final word = _queue[_index];
    return Scaffold(
      appBar: AppBar(title: Text('مراجعة ' + (_index + 1).toString() + '/' + _queue.length.toString())),
      body: GestureDetector(
        onTap: () => setState(() => _revealed = true),
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (!_revealed) {
            setState(() => _revealed = true);
          } else if (velocity > 250) {
            _answer(true);
          } else if (velocity < -250) {
            _answer(false);
          }
        },
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 500) _delete();
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(word.german, textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    if (_revealed) ...[
                      Text(word.translation, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 15),
                      Text(word.example, textDirection: TextDirection.ltr, textAlign: TextAlign.center),
                      const SizedBox(height: 30),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => _answer(false), child: const Text('لم أتذكر'))),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton(onPressed: () => _answer(true), child: const Text('تذكرت'))),
                      ]),
                    ] else
                      const Text('اضغط للكشف'),
                    const SizedBox(height: 20),
                    const Text('يمين: تذكرت • يسار: لم أتذكر • أسفل: حذف', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
