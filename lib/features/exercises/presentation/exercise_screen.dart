import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/models/word_model.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../core/services/speech_service.dart';

enum _QuestionType {
  translation,
  germanWord,
  sentenceTranslation,
  sentenceGerman,
  completeSentence,
  findSentence,
}

class _Question {
  const _Question({
    required this.type,
    required this.word,
    required this.options,
    required this.correctIndex,
    this.prompt,
    this.content,
  });

  final _QuestionType type;
  final WordModel word;
  final List<String> options;
  final int correctIndex;
  final String? prompt;
  final String? content;
}

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final _repository = WordRepository();
  final _random = Random();
  final _speech = SpeechService.instance;

  List<WordModel> _words = [];
  _Question? _currentQuestion;
  int _score = 0;
  int _answered = 0;
  int _streak = 0;
  int? _selected;
  bool _loading = true;
  int _questionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _speech.initialize();
    _load();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final words = await _repository.reviewWords();
      if (!mounted) return;

      final question = words.length >= 2 ? _makeQuestion(words) : null;

      setState(() {
        _words = words;
        _loading = false;
        _currentQuestion = question;
      });

      if (question != null) {
        _questionGeneration++;
        _scheduleAutoQuestionSpeech(question, _questionGeneration);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تعذر تحميل الاختبار'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    }
  }

  _Question _makeQuestion(List<WordModel> words) {
    final word = words[_random.nextInt(words.length)];
    final types = <_QuestionType>[
      _QuestionType.translation,
      _QuestionType.germanWord,
    ];

    if (word.example.trim().isNotEmpty &&
        word.exampleTranslation.trim().isNotEmpty) {
      types.addAll([
        _QuestionType.sentenceTranslation,
        _QuestionType.sentenceGerman,
        _QuestionType.completeSentence,
        _QuestionType.findSentence,
      ]);
    }

    switch (types[_random.nextInt(types.length)]) {
      case _QuestionType.translation:
        return _buildQuestion(
          _QuestionType.translation,
          word,
          'ما الترجمة الصحيحة للكلمة؟',
          word.german,
          word.translation,
          words.map((w) => w.translation),
        );
      case _QuestionType.germanWord:
        return _buildQuestion(
          _QuestionType.germanWord,
          word,
          'أي كلمة ألمانية تطابق المعنى؟',
          word.translation,
          word.german,
          words.map((w) => w.german),
        );
      case _QuestionType.sentenceTranslation:
        return _buildQuestion(
          _QuestionType.sentenceTranslation,
          word,
          'ما الترجمة الصحيحة لهذه الجملة؟',
          word.example,
          word.exampleTranslation,
          words.map((w) => w.exampleTranslation),
        );
      case _QuestionType.sentenceGerman:
        return _buildQuestion(
          _QuestionType.sentenceGerman,
          word,
          'أي جملة ألمانية تطابق هذه الترجمة؟',
          word.exampleTranslation,
          word.example,
          words.map((w) => w.example),
        );
      case _QuestionType.completeSentence:
        final masked = _mask(word.example, word.german);
        if (masked == word.example) {
          return _buildQuestion(
            _QuestionType.translation,
            word,
            'ما الترجمة الصحيحة للكلمة؟',
            word.german,
            word.translation,
            words.map((w) => w.translation),
          );
        }
        return _buildQuestion(
          _QuestionType.completeSentence,
          word,
          'أكمل الجملة بالكلمة المناسبة',
          masked,
          word.german,
          words.map((w) => w.german),
        );
      case _QuestionType.findSentence:
        return _buildQuestion(
          _QuestionType.findSentence,
          word,
          'اختر الجملة التي تحتوي على الكلمة المطلوبة',
          word.german,
          word.example,
          words.map((w) => w.example),
        );
    }
  }

  _Question _buildQuestion(
    _QuestionType type,
    WordModel word,
    String prompt,
    String content,
    String correct,
    Iterable<String> values,
  ) {
    final options = <String>[];
    final seen = <String>{};

    void add(String value) {
      final v = value.trim();
      if (v.isEmpty || !seen.add(v.toLowerCase())) return;
      options.add(v);
    }

    add(correct);
    final shuffled = values.toList()..shuffle(_random);
    for (final value in shuffled) {
      add(value);
      if (options.length == 4) break;
    }

    options.shuffle(_random);

    return _Question(
      type: type,
      word: word,
      options: options,
      correctIndex: options.indexOf(correct),
      prompt: prompt,
      content: content,
    );
  }

  String _mask(String sentence, String word) {
    final pattern = RegExp(
      r'\b' + RegExp.escape(word.trim()) + r'\b',
      caseSensitive: false,
    );
    return sentence.replaceFirst(pattern, '_____');
  }

  void _choose(int index) {
    if (_selected != null || _currentQuestion == null) return;

    final correct = index == _currentQuestion!.correctIndex;
    setState(() {
      _selected = index;
      _answered++;
      if (correct) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
  }

  void _next() {
    if (_words.length < 2) return;

    final question = _makeQuestion(_words);
    _questionGeneration++;

    setState(() {
      _currentQuestion = question;
      _selected = null;
    });

    _scheduleAutoQuestionSpeech(question, _questionGeneration);
  }

  void _scheduleAutoQuestionSpeech(
    _Question question,
    int generation,
  ) {
    final shouldSpeak = question.type == _QuestionType.translation ||
        question.type == _QuestionType.sentenceTranslation;

    if (!shouldSpeak) return;

    final content = question.content?.trim();
    if (content == null || content.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selected != null) return;

      _speech.speakGerman(
        content,
        activeKey: 'exercise-question',
        automaticKey: 'exercise-question-$generation',
      );
    });
  }

  String _typeName(_QuestionType type) {
    switch (type) {
      case _QuestionType.translation:
        return 'معنى الكلمة';
      case _QuestionType.germanWord:
        return 'اختيار الكلمة';
      case _QuestionType.sentenceTranslation:
        return 'ترجمة الجملة';
      case _QuestionType.sentenceGerman:
        return 'الجملة الصحيحة';
      case _QuestionType.completeSentence:
        return 'إكمال الجملة';
      case _QuestionType.findSentence:
        return 'استخدام الكلمة';
    }
  }

  bool _isGerman(String value) =>
      RegExp(r'[äöüÄÖÜß]').hasMatch(value) ||
      value.contains(RegExp(r'\b(ich|du|er|sie|wir|ihr|der|die|das|ein|eine)\b'));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_words.length < 2 || _currentQuestion == null) {
      return _empty();
    }

    final q = _currentQuestion!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اختبار المراجعة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 18),
            child: Center(
              child: Text(
                '$_score / $_answered',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            _hero(q),
            const SizedBox(height: 14),
            _questionCard(q),
            const SizedBox(height: 14),
            ...q.options.asMap().entries.map(
              (entry) => _option(q, entry.key, entry.value),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 10),
              _feedback(q),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('السؤال التالي'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero(_Question q) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B5FEF), Color(0xFF7567F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x225B5FEF),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختبر كلمات المراجعة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_words.length} كلمة • ${_typeName(q.type)}',
                  style: const TextStyle(
                    color: Color(0xFFEDEEFF),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (_streak > 0)
            Text(
              '🔥 $_streak',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _questionCard(_Question q) {
    final rtlContent = q.type == _QuestionType.sentenceGerman ||
        q.type == _QuestionType.translation ||
        q.type == _QuestionType.germanWord;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFE6E7F0)),
      ),
      child: Column(
        children: [
          Text(
            q.prompt ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Directionality(
            textDirection: rtlContent ? TextDirection.rtl : TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    q.content ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: q.content!.length > 45 ? 21 : 30,
                      height: 1.45,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF171A2A),
                    ),
                  ),
                ),
                if (_questionContentIsGerman(q)) ...[
                  const SizedBox(width: 10),
                  _speechButton(
                    text: q.content ?? '',
                    keyValue: 'exercise-question',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _questionContentIsGerman(_Question q) {
    return q.type == _QuestionType.translation ||
        q.type == _QuestionType.sentenceTranslation ||
        q.type == _QuestionType.completeSentence ||
        q.type == _QuestionType.findSentence;
  }

  Widget _speechButton({
    required String text,
    required String keyValue,
    bool compact = false,
  }) {
    return ValueListenableBuilder<String?>(
      valueListenable: _speech.activeKey,
      builder: (context, activeKey, _) {
        final active = activeKey == keyValue;

        return Material(
          color: active
              ? const Color(0xFFE9E8FF)
              : const Color(0xFFF0F1F7),
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          child: InkWell(
            onTap: () => _speech.speakGerman(
              text,
              activeKey: keyValue,
            ),
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            child: Padding(
              padding: EdgeInsets.all(compact ? 7 : 9),
              child: Icon(
                active
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                color: const Color(0xFF5B5FEF),
                size: compact ? 17 : 21,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _option(_Question q, int index, String value) {
    final selected = _selected == index;
    final optionIsGerman =
        q.type == _QuestionType.germanWord ||
        q.type == _QuestionType.sentenceGerman ||
        q.type == _QuestionType.completeSentence ||
        q.type == _QuestionType.findSentence;
    final correct = _selected != null && index == q.correctIndex;
    final wrong = selected && !correct;

    final bg = correct
        ? const Color(0xFFE9F9F5)
        : wrong
            ? const Color(0xFFFFECEE)
            : Colors.white;
    final border = correct
        ? const Color(0xFF16A88F)
        : wrong
            ? const Color(0xFFE95D6A)
            : const Color(0xFFE4E5ED);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: border,
            width: correct || wrong ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selected == null ? () => _choose(index) : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Directionality(
                      textDirection: optionIsGerman
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (optionIsGerman)
                    _speechButton(
                      text: value,
                      keyValue: 'exercise-option-$index',
                      compact: true,
                    ),
                  if (correct)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A88F),
                    ),
                  if (wrong)
                    const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFFE95D6A),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedback(_Question q) {
    final correct = _selected == q.correctIndex;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFE9F9F5) : const Color(0xFFFFF5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: correct ? const Color(0xFFB8E8DC) : const Color(0xFFF2D4AD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : Icons.lightbulb_rounded,
                color: correct
                    ? const Color(0xFF16A88F)
                    : const Color(0xFFE89524),
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'إجابة صحيحة' : 'الإجابة الصحيحة',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  q.word.german,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _speechButton(
                text: q.word.german,
                keyValue: 'exercise-feedback-word',
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            q.word.translation,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (q.word.example.trim().isNotEmpty) ...[
            const SizedBox(height: 11),
            const Divider(height: 1),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    q.word.example,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _speechButton(
                  text: q.word.example,
                  keyValue: 'exercise-feedback-sentence',
                  compact: true,
                ),
              ],
            ),
            if (q.word.exampleTranslation.trim().isNotEmpty)
              Text(
                q.word.exampleTranslation,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اختبار المراجعة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: const Color(0xFFE5E6EF)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_rounded, color: Color(0xFF5B5FEF), size: 52),
                SizedBox(height: 18),
                Text(
                  'لا توجد كلمات كافية للاختبار',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'أضف كلمتين على الأقل إلى المراجعة، وبعدها ستظهر الأسئلة هنا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
