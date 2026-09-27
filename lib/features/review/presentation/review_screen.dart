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
    final empty = _queue.isEmpty || _index < 0 || _index >= _queue.length;
    if (empty) {
      return Scaffold(
        appBar: AppBar(title: const Text('المراجعة')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 84, height: 84,
            decoration: BoxDecoration(color: const Color(0xFFE9F9F5), borderRadius: BorderRadius.circular(28)),
            child: const Icon(Icons.check_rounded, size: 42, color: Color(0xFF16A88F))),
          const SizedBox(height: 18),
          const Text('أحسنت! لا توجد مراجعات الآن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('عد لاحقًا وستجد الكلمات عندما يحين وقتها.', style: TextStyle(color: Colors.black54)),
        ])),
      );
    }

    final word = _queue[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('المراجعة ' + (_index + 1).toString() + '/' + _queue.length.toString(),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: .96, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            ),
            child: Card(
              key: ValueKey(word.id.toString() + '-' + _revealed.toString()),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 62, height: 62,
                    decoration: BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.style_rounded, color: Color(0xFF5B5FEF), size: 30)),
                  const SizedBox(height: 25),
                  Text(word.german, textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 28),
                  if (_revealed) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(18)),
                      child: Column(children: [
                        Text(word.translation, textDirection: TextDirection.rtl,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700, color: const Color(0xFF5B5FEF))),
                        const SizedBox(height: 12),
                        Text(word.example, textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => _answer(false),
                        icon: const Icon(Icons.close_rounded), label: const Text('لم أتذكر'))),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton.icon(
                        onPressed: () => _answer(true),
                        icon: const Icon(Icons.check_rounded), label: const Text('تذكرت'))),
                    ]),
                  ] else ...[
                    const Text('اضغط على البطاقة للكشف', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    const Icon(Icons.touch_app_rounded, color: Colors.black38),
                  ],
                  const Spacer(),
                  const Text('يمين: تذكرت • يسار: لم أتذكر • اسحب للأسفل للحذف',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
