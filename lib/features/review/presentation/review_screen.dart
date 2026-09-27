import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/word_repository.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  final _words = WordRepository();
  final _reviews = ReviewRepository();

  List<WordModel> _queue = [];
  int _index = 0;
  bool _revealed = false;
  bool _isAnimating = false;

  late final AnimationController _exitController;
  Animation<Offset>? _exitAnimation;

  Offset _dragOffset = Offset.zero;

  static const _primary = Color(0xFF5B5FEF);
  static const _green = Color(0xFF16A88F);
  static const _red = Color(0xFFE45757);

  @override
  void initState() {
    super.initState();

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _load();
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final queue = await _words.dueWords();

    if (!mounted) return;

    setState(() {
      _queue = queue;
      _index = 0;
      _revealed = false;
      _dragOffset = Offset.zero;
    });
  }

  Future<void> _answer(bool remembered) async {
    if (_isAnimating || _queue.isEmpty || _index >= _queue.length) {
      return;
    }

    final word = _queue[_index];
    final direction =
        remembered ? const Offset(1.25, 0.02) : const Offset(-1.25, 0.02);

    await _animateCardExit(direction);

    await _reviews.review(word.id, remembered);

    if (!mounted) return;

    setState(() {
      _index++;
      _revealed = false;
      _dragOffset = Offset.zero;
      _isAnimating = false;
      _exitAnimation = null;
    });
  }

  Future<void> _delete() async {
    if (_isAnimating || _queue.isEmpty || _index >= _queue.length) {
      return;
    }

    final word = _queue[_index];

    await _animateCardExit(const Offset(0, 1.25));
    await _words.remove(word.id);

    if (!mounted) return;

    setState(() {
      _queue.removeAt(_index);
      _revealed = false;
      _dragOffset = Offset.zero;
      _isAnimating = false;
      _exitAnimation = null;

      if (_index >= _queue.length && _queue.isNotEmpty) {
        _index = _queue.length - 1;
      }
    });
  }

  Future<void> _animateCardExit(Offset target) async {
    if (!mounted) return;

    final start = _dragOffset;

    setState(() {
      _isAnimating = true;
      _exitAnimation = Tween<Offset>(
        begin: start,
        end: target,
      ).animate(
        CurvedAnimation(
          parent: _exitController,
          curve: Curves.easeInCubic,
        ),
      );
    });

    await _exitController.forward(from: 0);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;

    setState(() {
      _dragOffset += details.delta;

      // Keep the gesture bounded so the card stays visually connected
      // to the finger while still allowing a strong swipe.
      _dragOffset = Offset(
        _dragOffset.dx.clamp(-360.0, 360.0),
        _dragOffset.dy.clamp(-90.0, 260.0),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    final velocity = details.primaryVelocity ?? 0;
    final horizontalDistance = _dragOffset.dx.abs();
    final verticalDistance = _dragOffset.dy;

    if (!_revealed &&
        horizontalDistance < 18 &&
        verticalDistance.abs() < 18 &&
        velocity.abs() < 100) {
      setState(() => _revealed = true);
      return;
    }

    if (_dragOffset.dx > 115 || velocity > 700) {
      _answer(true);
    } else if (_dragOffset.dx < -115 || velocity < -700) {
      _answer(false);
    } else if (_dragOffset.dy > 135) {
      _delete();
    } else {
      _returnCardToCenter();
    }
  }

  Future<void> _returnCardToCenter() async {
    if (_isAnimating || _dragOffset == Offset.zero) return;

    final start = _dragOffset;

    setState(() {
      _isAnimating = true;
      _exitAnimation = Tween<Offset>(
        begin: start,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _exitController,
          curve: Curves.easeOutBack,
        ),
      );
    });

    await _exitController.forward(from: 0);

    if (!mounted) return;

    setState(() {
      _dragOffset = Offset.zero;
      _isAnimating = false;
      _exitAnimation = null;
    });
  }

  void _revealCard() {
    if (_isAnimating || _revealed) return;

    setState(() => _revealed = true);
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(title: const Text('المراجعة')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F9F5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 46,
                  color: _green,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'أحسنت! لا توجد مراجعات الآن',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'عد لاحقًا وستجد الكلمات عندما يحين وقتها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(WordModel word) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.style_rounded,
              color: _primary,
              size: 31,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            word.german,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: _revealed
                ? _buildAnswerArea(word)
                : const Column(
                    children: [
                      Text(
                        'اضغط على البطاقة للكشف',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 9),
                      Icon(
                        Icons.touch_app_rounded,
                        color: Colors.black38,
                        size: 27,
                      ),
                    ],
                  ),
          ),
          const Spacer(),
          const Text(
            '➡️ يمين: تذكرت  •  ⬅️ يسار: لم أتذكر  •  ⬇️ أسفل: حذف',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(WordModel word) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: const Color(0xFFE9EAF2),
            ),
          ),
          child: Column(
            children: [
              Text(
                word.translation,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
              ),
              const SizedBox(height: 9),
              Text(
                word.example,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  height: 1.45,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _answer(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(
                    color: _red,
                    width: 1.4,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
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
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('تذكرت'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwipeHint() {
    final horizontal = (_dragOffset.dx / 130).clamp(-1.0, 1.0);
    final vertical = (_dragOffset.dy / 150).clamp(0.0, 1.0);

    if (horizontal.abs() < 0.08 && vertical < 0.08) {
      return const SizedBox.shrink();
    }

    final bool deleting = vertical > horizontal.abs();
    final bool remembered = horizontal > 0;
    final color = deleting
        ? Colors.orange
        : remembered
            ? _green
            : _red;

    final text = deleting
        ? 'حذف'
        : remembered
            ? 'تذكرت'
            : 'لم أتذكر';

    final icon = deleting
        ? Icons.delete_outline_rounded
        : remembered
            ? Icons.check_rounded
            : Icons.close_rounded;

    return Positioned(
      top: 22,
      left: 22,
      right: 22,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: 0.92,
          child: Align(
            alignment: remembered
                ? Alignment.topRight
                : deleting
                    ? Alignment.topCenter
                    : Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.94),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(WordModel word, {required bool active}) {
    if (!active) {
      return Transform.scale(
        scale: 0.94,
        child: Opacity(
          opacity: 0.55,
          child: Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(
                color: Color(0xFFE9EAF2),
              ),
            ),
            child: _buildBackCardPreview(word),
          ),
        ),
      );
    }

    final double horizontalProgress =
        (_dragOffset.dx.abs() / 320).clamp(0.0, 1.0).toDouble();
    final double verticalProgress =
        (_dragOffset.dy / 220).clamp(0.0, 1.0).toDouble();

    final double scale = 1.0 - (horizontalProgress * 0.035);
    final rotation = _dragOffset.dx * 0.00075;

    final borderColor = _dragOffset.dx > 30
        ? _green.withOpacity((_dragOffset.dx / 150).clamp(0.0, 1.0).toDouble())
        : _dragOffset.dx < -30
            ? _red.withOpacity(
                (_dragOffset.dx.abs() / 150).clamp(0.0, 1.0).toDouble(),
              )
            : verticalProgress > 0.15
                ? Colors.orange.withOpacity(verticalProgress)
                : Colors.transparent;

    Widget card = Card(
      elevation: 10,
      shadowColor: Colors.black.withOpacity(0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: borderColor,
          width: 2.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _buildCardContent(word),
      ),
    );

    if (_exitAnimation != null) {
      card = AnimatedBuilder(
        animation: _exitAnimation!,
        builder: (context, child) {
          final offset = _exitAnimation!.value;
          return Transform.translate(
            offset: Offset(
              offset.dx * MediaQuery.sizeOf(context).width,
              offset.dy * MediaQuery.sizeOf(context).height,
            ),
            child: Transform.rotate(
              angle: offset.dx * 0.35,
              child: child,
            ),
          );
        },
        child: card,
      );
    } else {
      card = Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: card,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        card,
        if (_exitAnimation == null) _buildSwipeHint(),
      ],
    );
  }

  Widget _buildBackCardPreview(WordModel word) {
    return SizedBox(
      height: 520,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.style_rounded,
                color: _primary,
                size: 27,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              word.german,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'البطاقة التالية',
              style: TextStyle(
                color: Colors.black38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = _queue.isEmpty || _index < 0 || _index >= _queue.length;

    if (empty) {
      return _buildEmptyState();
    }

    final word = _queue[_index];
    final nextWord =
        _index + 1 < _queue.length ? _queue[_index + 1] : null;

    final double nextScale =
        0.94 + ((_dragOffset.dx.abs() / 320).clamp(0.0, 1.0).toDouble() * 0.04);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'المراجعة ' + (_index + 1).toString() + '/' + _queue.length.toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: ((_index + 1) / _queue.length).clamp(0.0, 1.0).toDouble(),
                backgroundColor: const Color(0xFFE5E7EF),
                valueColor: const AlwaysStoppedAnimation(_primary),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double cardHeight =
                          constraints.maxHeight.clamp(420.0, 560.0).toDouble();

                      return SizedBox(
                        height: cardHeight,
                        width: double.infinity,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _revealCard,
                          onPanUpdate: _handleDragUpdate,
                          onPanEnd: _handleDragEnd,
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              if (nextWord != null)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  transform: Matrix4.identity()
                                    ..translate(0.0, 12.0)
                                    ..scale(nextScale),
                                  transformAlignment: Alignment.center,
                                  child: _buildCard(
                                    nextWord,
                                    active: false,
                                  ),
                                ),
                              _buildCard(word, active: true),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _revealed
                    ? const Text(
                        'اسحب البطاقة أو استخدم أزرار الإجابة',
                        key: ValueKey('revealed_hint'),
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      )
                    : const Text(
                        'اضغط للكشف ثم اسحب البطاقة يمينًا أو يسارًا',
                        key: ValueKey('hidden_hint'),
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
