import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/discovery_repository.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _repository = DiscoveryRepository();

  WordModel? _word;
  int _available = 0;
  int _step = 0;

  bool _loading = true;
  bool _busy = false;
  bool _showMeaning = false;
  bool _isDragging = false;

  double _dragDx = 0;

  static const _primary = Color(0xFF5B5FEF);
  static const _green = Color(0xFF16A88F);
  static const _red = Color(0xFFE45757);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _showMeaning = false;
    });

    final word = await _repository.nextWord();
    final available = await _repository.availableCount();
    final step = await _repository.currentStep();

    if (!mounted) return;

    setState(() {
      _word = word;
      _available = available;
      _step = step;
      _loading = false;
      _busy = false;
      _showMeaning = false;
      _dragDx = 0;
      _isDragging = false;
    });
  }

  Future<void> _answer(bool known) async {
    final word = _word;
    if (word == null || _busy) return;

    setState(() {
      _busy = true;
      _showMeaning = !known;
    });

    await _repository.answer(word, known: known);

    if (!mounted) return;

    await Future.delayed(
      Duration(milliseconds: known ? 180 : 650),
    );

    if (!mounted) return;
    await _load();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_busy || _word == null) return;

    setState(() {
      _isDragging = true;
      _dragDx = (_dragDx + details.delta.dx).clamp(-260.0, 260.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_busy || _word == null) return;

    final velocity = details.primaryVelocity ?? 0;

    if (_dragDx > 145 || velocity > 1500) {
      _answer(true);
    } else if (_dragDx < -145 || velocity < -1500) {
      _answer(false);
    } else {
      setState(() {
        _dragDx = 0;
        _isDragging = false;
      });
    }
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اكتشاف الكلمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE9E8FF), Color(0xFFF3F2FF)],
                  ),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 50,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'لا توجد كلمات متاحة الآن',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'أضف كلمات جديدة إلى ملف قاعدة الكلمات، وستظهر تلقائيًا في الاكتشاف.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('اكتشاف الكلمات'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final word = _word;
    if (word == null) {
      return _buildEmptyState();
    }

    final dragProgress = (_dragDx.abs() / 160).clamp(0.0, 1.0);
    final isKnownDrag = _dragDx > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'اكتشاف الكلمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),

      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'هل تعرف هذه الكلمة؟',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تم اكتشاف $_step كلمة / قرار حتى الآن',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE8E9F2),
                    ),
                  ),
                  child: Text(
                    '$_available متاحة',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onPanUpdate: _handleDragUpdate,
              onPanEnd: _handleDragEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..translate(_dragDx, 0.0)
                  ..rotateZ(_dragDx * 0.00065),
                transformAlignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 465),
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isDragging
                        ? (isKnownDrag
                            ? _green.withOpacity(0.5)
                            : _red.withOpacity(0.5))
                        : const Color(0xFFE8E9F2),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: 1 + dragProgress * 0.035,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFECEBFF), Color(0xFFF4F2FF)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: _primary,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Deutsch',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      word.german,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                    ),
                    const SizedBox(height: 13),
                    if (_showMeaning) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'المعنى',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              word.translation,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              word.example,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                height: 1.5,
                                fontSize: 13,
                              ),
                            ),
                            if (word.exampleTranslation.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                word.exampleTranslation,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  height: 1.45,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Text(
                        'اسحب يمينًا إذا كنت تعرفها',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'اسحب يسارًا إذا لم تكن تعرفها',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (_isDragging) ...[
                      const SizedBox(height: 20),
                      AnimatedOpacity(
                        opacity: dragProgress,
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isKnownDrag
                                ? _green.withOpacity(0.95)
                                : _red.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            isKnownDrag ? 'أعرفها' : 'لا أعرفها',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _answer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(
                        color: _red,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('لا أعرفها'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _answer(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('أعرفها'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            const Text(
              '«أعرفها» تؤجل الكلمة 1000 بطاقة. «لا أعرفها» تنقلها مباشرة إلى المراجعة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
