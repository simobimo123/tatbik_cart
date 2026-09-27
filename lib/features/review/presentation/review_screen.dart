import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/config/learning_config.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/word_repository.dart';
import 'add_review_word_screen.dart';
import '../../export/presentation/export_words_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    this.categoryId,
    this.difficulty,
  });

  final int? categoryId;
  final String? difficulty;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  final _words = WordRepository();
  final _reviews = ReviewRepository();

  final Map<int, int> _sessionReturnAtStep = {};
  final Map<int, int> _sessionAnswerCount = {};
  final Map<int, bool> _germanFront = {};
  final Random _random = Random();

  List<WordModel> _queue = [];
  int _sessionStep = 0;
  int _sessionAnswered = 0;

  bool _loading = true;
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
      duration: const Duration(milliseconds: 300),
    );

    _load(resetSession: true);
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  bool _isGermanFront(WordModel word) {
    return _germanFront.putIfAbsent(word.id, () => _random.nextBool());
  }

  Future<void> _load({required bool resetSession}) async {
    if (mounted) {
      setState(() => _loading = true);
    }

    final queue = await _words.dueWords(
      limit: 300,
      categoryId: widget.categoryId,
      difficulty: widget.difficulty,
    );

    if (!mounted) return;

    setState(() {
      _queue = queue;
      _loading = false;
      _revealed = false;
      _dragOffset = Offset.zero;

      if (resetSession) {
        _sessionReturnAtStep.clear();
        _sessionAnswerCount.clear();
        _sessionStep = 0;
        _sessionAnswered = 0;
      }

      _prepareNextCard();
    });
  }

  Future<void> _reloadAfterAddingWord() async {
    await _load(resetSession: true);
  }

  Future<void> _answer(bool remembered) async {
    if (_isAnimating || _queue.isEmpty) return;

    final word = _queue.first;
    final answerCount = _sessionAnswerCount[word.id] ?? 0;
    final hasBeenAnsweredBefore = answerCount > 0;

    final direction =
        remembered ? const Offset(500, 40) : const Offset(-500, 40);

    setState(() => _isAnimating = true);

    final saveFuture = _reviews.review(word.id, remembered);

    await _animateCardExit(direction);

    if (!mounted) return;

    setState(() {
      _queue.removeAt(0);

      // كل إجابة ناجحة في هذه الجلسة تمثل بطاقة أخرى ظهرت.
      _sessionStep++;
      _sessionAnswered++;

      _sessionAnswerCount[word.id] = answerCount + 1;

      if (remembered && hasBeenAnsweredBefore) {
        // بعد أن يعرفها المستخدم للمرة الثانية:
        // تُنقل لنهاية الحزمة ولا تعود لها أولوية داخل الجلسة.
        _sessionReturnAtStep.remove(word.id);
        _queue.add(word);
      } else {
        final delay = remembered
            ? LearningConfig.reviewRememberedDelayCards
            : LearningConfig.reviewForgottenDelayCards;

        // لا نعد البطاقة الحالية نفسها. يبدأ العد من البطاقات
        // التي ستظهر بعدها.
        _sessionReturnAtStep[word.id] = _sessionStep + delay;
        _queue.add(word);
      }

      _revealed = false;
      _dragOffset = Offset.zero;
      _isAnimating = false;
      _exitAnimation = null;

      _prepareNextCard();
    });

    await saveFuture;

    // عندما نقترب من نهاية الدفعة، نطلب بطاقات مستحقة أخرى من قاعدة
    // البيانات حتى لا يتوقف المستخدم عند حد الدفعة 300.
    if (mounted && _queue.length < 50) {
      await _appendMoreDueWords();
    }
  }

  Future<void> _appendMoreDueWords() async {
    final more = await _words.dueWords(
      limit: 300,
      categoryId: widget.categoryId,
      difficulty: widget.difficulty,
    );
    if (!mounted || more.isEmpty) return;

    setState(() {
      final existingIds = _queue.map((word) => word.id).toSet();

      for (final word in more) {
        if (!existingIds.contains(word.id)) {
          _queue.add(word);
          existingIds.add(word.id);
        }
      }

      _prepareNextCard();
    });
  }

  void _prepareNextCard() {
    if (_queue.isEmpty) return;

    var bestDueIndex = -1;
    var bestDueStep = 1 << 60;
    var firstAvailableIndex = -1;

    for (var i = 0; i < _queue.length; i++) {
      final word = _queue[i];
      final dueStep = _sessionReturnAtStep[word.id];

      if (dueStep == null) {
        if (firstAvailableIndex < 0) {
          firstAvailableIndex = i;
        }
        continue;
      }

      if (dueStep <= _sessionStep && dueStep < bestDueStep) {
        bestDueStep = dueStep;
        bestDueIndex = i;
      }
    }

    final targetIndex =
        bestDueIndex >= 0 ? bestDueIndex : firstAvailableIndex;

    if (targetIndex < 0 || targetIndex == 0) return;

    final word = _queue.removeAt(targetIndex);
    _queue.insert(0, word);
  }

  int? _findEligibleIndex() {
    var firstAvailable = -1;

    for (var i = 0; i < _queue.length; i++) {
      final dueStep = _sessionReturnAtStep[_queue[i].id];

      if (dueStep == null) {
        if (firstAvailable < 0) {
          firstAvailable = i;
        }
        continue;
      }

      if (dueStep <= _sessionStep) {
        return i;
      }
    }

    return firstAvailable >= 0 ? firstAvailable : null;
  }

  Future<void> _delete() async {
    if (_isAnimating || _queue.isEmpty) return;

    final word = _queue.first;

    await _animateCardExit(const Offset(0, 500));
    await _words.remove(word.id);

    if (!mounted) return;

    setState(() {
      _queue.removeAt(0);
      _sessionReturnAtStep.remove(word.id);
      _sessionAnswerCount.remove(word.id);
      _germanFront.remove(word.id);
      _revealed = false;
      _dragOffset = Offset.zero;
      _isAnimating = false;
      _exitAnimation = null;

      _prepareNextCard();
    });
  }

  Future<void> _animateCardExit(Offset target) async {
    if (!mounted) return;

    final start = _dragOffset;

    setState(() {
      _exitAnimation = Tween<Offset>(
        begin: start,
        end: target,
      ).animate(
        CurvedAnimation(
          parent: _exitController,
          curve: Curves.easeOutCubic,
        ),
      );
    });

    await _exitController.forward(from: 0);
    _exitController.reset();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;

    setState(() {
      _dragOffset += details.delta;
      _dragOffset = Offset(
        _dragOffset.dx.clamp(-280.0, 280.0),
        _dragOffset.dy.clamp(-70.0, 220.0),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    final velocity = details.primaryVelocity ?? 0;
    final horizontalDistance = _dragOffset.dx.abs();
    final verticalDistance = _dragOffset.dy;

    if (!_revealed &&
        horizontalDistance < 24 &&
        verticalDistance.abs() < 24 &&
        velocity.abs() < 120) {
      setState(() => _revealed = true);
      return;
    }

    if (_dragOffset.dx > 190 ||
        (_dragOffset.dx > 135 && velocity > 1400)) {
      _answer(true);
    } else if (_dragOffset.dx < -190 ||
        (_dragOffset.dx < -135 && velocity < -1400)) {
      _answer(false);
    } else if (_dragOffset.dy > 210 &&
        _dragOffset.dy > _dragOffset.dx.abs() * 0.95) {
      _delete();
    } else {
      _returnCardToCenter();
    }
  }

  Future<void> _returnCardToCenter() async {
    if (_isAnimating || _dragOffset == Offset.zero) return;

    setState(() {
      _isAnimating = true;
      _exitAnimation = Tween<Offset>(
        begin: _dragOffset,
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

    _exitController.reset();
  }

  void _revealCard() {
    if (_isAnimating || _revealed) return;
    setState(() => _revealed = true);
  }

  Future<void> _openAddWord() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddReviewWordScreen(),
      ),
    );

    if (added == true && mounted) {
      await _reloadAfterAddingWord();
    }
  }

  Future<void> _openExport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExportWordsScreen(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المراجعة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _openAddWord,
            tooltip: 'إضافة كلمة للمراجعة',
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: _openExport,
            tooltip: 'تصدير الكلمات',
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
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
                  color: const Color(0xFFE9F9F5),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 50,
                  color: _green,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'لا توجد بطاقات مستحقة الآن',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'يمكنك إضافة كلمة مباشرة إلى المراجعة أو العودة لاحقًا عند حلول موعد الكلمات التالية.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _openAddWord,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('إضافة كلمة للمراجعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingState() {
    final delayedCount = _queue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المراجعة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _openAddWord,
            tooltip: 'إضافة كلمة للمراجعة',
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: _openExport,
            tooltip: 'تصدير الكلمات',
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                size: 58,
                color: _primary,
              ),
              const SizedBox(height: 18),
              const Text(
                'انتهت البطاقات المتاحة لهذه اللحظة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '$delayedCount بطاقة ما زالت مؤجلة حتى تمر البطاقات المطلوبة قبل عودتها.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _openAddWord,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('إضافة بطاقة جديدة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(WordModel word) {
    final germanOnFront = _isGermanFront(word);
    final frontText = germanOnFront ? word.german : word.translation;
    final frontDirection =
        germanOnFront ? TextDirection.ltr : TextDirection.rtl;
    final frontLabel = germanOnFront ? 'Deutsch' : 'الترجمة';

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
            frontLabel,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            frontText,
            textDirection: frontDirection,
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
    final germanOnFront = _isGermanFront(word);
    final answerText = germanOnFront ? word.translation : word.german;
    final answerDirection =
        germanOnFront ? TextDirection.rtl : TextDirection.ltr;
    final answerLabel = germanOnFront ? 'الترجمة' : 'Deutsch';

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
                answerLabel,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                answerText,
                textDirection: answerDirection,
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
              if (word.exampleTranslation.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  word.exampleTranslation,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    height: 1.45,
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
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
                color: color.withValues(alpha: 0.94),
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

    final horizontalProgress =
        (_dragOffset.dx.abs() / 320).clamp(0.0, 1.0).toDouble();
    final verticalProgress =
        (_dragOffset.dy / 220).clamp(0.0, 1.0).toDouble();
    final scale = 1.0 - (horizontalProgress * 0.035);
    final rotation = _dragOffset.dx * 0.00075;

    final borderColor = _dragOffset.dx > 30
        ? _green.withValues(alpha: 
            (_dragOffset.dx / 150).clamp(0.0, 1.0).toDouble(),
          )
        : _dragOffset.dx < -30
            ? _red.withValues(alpha: 
                (_dragOffset.dx.abs() / 150)
                    .clamp(0.0, 1.0)
                    .toDouble(),
              )
            : verticalProgress > 0.15
                ? Colors.orange.withValues(alpha: verticalProgress)
                : Colors.transparent;

    Widget card = Card(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.16),
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
            offset: offset,
            child: Transform.rotate(
              angle: offset.dx * 0.00075,
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
    final germanOnFront = _isGermanFront(word);
    final previewText = germanOnFront ? word.german : word.translation;
    final previewDirection =
        germanOnFront ? TextDirection.ltr : TextDirection.rtl;

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
              previewText,
              textDirection: previewDirection,
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_queue.isEmpty) {
      return _buildEmptyState();
    }

    final eligibleIndex = _findEligibleIndex();

    if (eligibleIndex == null) {
      return _buildWaitingState();
    }

    if (eligibleIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isAnimating) {
          setState(_prepareNextCard);
        }
      });
    }

    final word = _queue.first;
    final nextWord =
        _queue.length > 1 ? _queue[1] : null;

    final nextScale =
        0.94 +
        ((_dragOffset.dx.abs() / 320).clamp(0.0, 1.0).toDouble() * 0.04);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.categoryId != null || widget.difficulty != null
                  ? 'المراجعة المفلترة'
                  : 'المراجعة',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'تمت الإجابة عن $_sessionAnswered بطاقة',
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openAddWord,
            tooltip: 'إضافة كلمة للمراجعة',
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: _openExport,
            tooltip: 'تصدير الكلمات',
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
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
                      final cardHeight =
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
                                    ..translateByDouble(0.0, 12.0, 0.0, 1.0)
                                    ..scaleByDouble(nextScale, nextScale, nextScale, 1.0),
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
