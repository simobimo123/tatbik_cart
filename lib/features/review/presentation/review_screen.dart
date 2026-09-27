import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/word_repository.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with SingleTickerProviderStateMixin {
  final _words = WordRepository();
  final _reviews = ReviewRepository();
  
  List<WordModel> _queue = [];
  int _index = 0;
  bool _revealed = false;

  late AnimationController _controller;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final queue = await _words.dueWords();
    if (mounted) setState(() => _queue = queue);
  }

  Future<void> _answer(bool remembered) async {
    if (_queue.isEmpty || _index >= _queue.length) return;
    
    final targetOffset = remembered ? const Offset(500, 0) : const Offset(-500, 0);
    await _animateCardExit(targetOffset);

    await _reviews.review(_queue[_index].id, remembered);
    if (mounted) {
      setState(() {
        _index++;
        _revealed = false;
        _dragOffset = Offset.zero;
      });
    }
  }

  Future<void> _delete() async {
    if (_queue.isEmpty || _index >= _queue.length) return;
    
    await _animateCardExit(const Offset(0, 500));
    await _words.remove(_queue[_index].id);
    
    if (mounted) {
      setState(() {
        _queue.removeAt(_index);
        if (_index >= _queue.length) _index = _queue.length - 1;
        _revealed = false;
        _dragOffset = Offset.zero;
      });
    }
  }

  Future<void> _animateCardExit(Offset targetOffset) async {
    final startOffset = _dragOffset;
    final animation = Tween<Offset>(begin: startOffset, end: targetOffset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    animation.addListener(() {
      setState(() => _dragOffset = animation.value);
    });

    _controller.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final empty = _queue.isEmpty || _index < 0 || _index >= _queue.length;
    
    if (empty) {
      return Scaffold(
        appBar: AppBar(title: const Text('المراجعة')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F9F5),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.check_rounded, size: 42, color: Color(0xFF16A88F)),
              ),
              const SizedBox(height: 18),
              const Text('أحسنت! لا توجد مراجعات الآن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text('عد لاحقًا وستجد الكلمات عندما يحين وقتها.', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    final word = _queue[_index];
    
    Color borderColor = Colors.transparent;
    double dragPercent = (_dragOffset.dx / 150).clamp(-1.0, 1.0);
    if (_dragOffset.dx > 30) {
      borderColor = Colors.green.withOpacity(dragPercent.abs());
    } else if (_dragOffset.dx < -30) {
      borderColor = Colors.red.withOpacity(dragPercent.abs());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ضمان ظهور خلفية الصفحة بوضوح
      appBar: AppBar(
        title: Text(
          'المراجعة ${_index + 1}/${_queue.length}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _revealed = true),
              onPanUpdate: (details) {
                setState(() {
                  _dragOffset += details.delta;
                });
              },
              onPanEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                
                if (!_revealed && _dragOffset.dx.abs() < 15 && _dragOffset.dy.abs() < 15) {
                  setState(() {
                    _revealed = true;
                    _dragOffset = Offset.zero;
                  });
                  return;
                }

                if (_dragOffset.dx > 100 || velocity > 350) {
                  _answer(true);
                } else if (_dragOffset.dx < -100 || velocity < -350) {
                  _answer(false);
                } else if (_dragOffset.dy > 130) {
                  _delete();
                } else {
                  setState(() => _dragOffset = Offset.zero);
                }
              },
              child: Transform.translate(
                offset: _dragOffset,
                child: Transform.rotate(
                  angle: _dragOffset.dx * 0.0004,
                  child: SizedBox(
                    height: 520, // تحديد ارتفاع ثابت ومناسب للبطاقة لمنع تمددها بشكل خاطئ واختفاء محتواها
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(color: borderColor, width: 2.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF0FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.style_rounded, color: Color(0xFF5B5FEF), size: 30),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              word.german,
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_revealed) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FC),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      word.translation,
                                      textDirection: TextDirection.rtl,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF5B5FEF),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      word.example,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(height: 1.4, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _answer(false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                      label: const Text('لم أتذكر'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () => _answer(true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      icon: const Icon(Icons.check_rounded),
                                      label: const Text('تذكرت'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const Text(
                                'اضغط على البطاقة للكشف',
                                style: TextStyle(color: Colors.black54, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              const Icon(Icons.touch_app_rounded, color: Colors.black38, size: 26),
                            ],
                            const Spacer(),
                            const Text(
                              '➡️ يمين: تذكرت  •  ⬅️ يسار: لم أتذكر  •  ⬇️ أسفل: للحذف',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}