import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/models/word_model.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/speech_answer_evaluator.dart';
import '../../../core/services/speech_recognition_service.dart';

enum _QuestionType {
  translation,
  germanWord,
  sentenceTranslation,
  sentenceGerman,
  completeSentence,
  findSentence,
  audioMatch,
  speakWord,
  speakSentence,
  repeatAudio,
}

class _Question {
  const _Question({
    required this.type,
    required this.word,
    required this.options,
    required this.correctIndex,
    this.prompt,
    this.content,
    this.matchingWords = const [],
    this.matchingTranslations = const [],
    this.voiceTarget,
  });

  final _QuestionType type;
  final WordModel word;
  final List<String> options;
  final int correctIndex;
  final String? prompt;
  final String? content;
  final List<WordModel> matchingWords;
  final List<String> matchingTranslations;
  final String? voiceTarget;
}

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  static int _speechSessionCounter = 0;

  final _repository = WordRepository();
  final _random = Random();
  final _speech = SpeechService.instance;
  final _voiceRecognition = SpeechRecognitionService.instance;
  final int _speechSessionId = ++_speechSessionCounter;

  Timer? _voiceTimer;
  bool _voiceFinishing = false;
  bool _voiceAnswered = false;
  String? _voiceTranscript;
  bool? _voiceCorrect;

  List<WordModel> _words = [];
  _Question? _currentQuestion;
  int _score = 0;
  int _answered = 0;
  int _streak = 0;
  int? _selected;
  int? _selectedAudioIndex;
  int? _wrongAudioIndex;
  int? _wrongTranslationIndex;
  final Map<int, int> _matchedPairs = {};
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
    _voiceTimer?.cancel();
    _voiceRecognition.cancelListening();
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

    if (_audioMatchEligible(words).length >= 4) {
      types.add(_QuestionType.audioMatch);
    }

    types.add(_QuestionType.speakWord);

    if (word.example.trim().isNotEmpty &&
        word.exampleTranslation.trim().isNotEmpty) {
      types.add(_QuestionType.speakSentence);
    }

    types.add(_QuestionType.repeatAudio);

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
      case _QuestionType.audioMatch:
        return _buildAudioMatchQuestion(words);
      case _QuestionType.speakWord:
        return _Question(
          type: _QuestionType.speakWord,
          word: word,
          options: const [],
          correctIndex: -1,
          prompt: 'قل الترجمة بالألمانية',
          content: word.translation,
          voiceTarget: word.german,
        );
      case _QuestionType.speakSentence:
        return _Question(
          type: _QuestionType.speakSentence,
          word: word,
          options: const [],
          correctIndex: -1,
          prompt: 'قل الجملة بالألمانية التي تعني:',
          content: word.exampleTranslation,
          voiceTarget: word.example,
        );
      case _QuestionType.repeatAudio:
        final canRepeatSentence =
            word.example.trim().isNotEmpty &&
            word.exampleTranslation.trim().isNotEmpty;
        final repeatSentence =
            canRepeatSentence && _random.nextBool();

        return _Question(
          type: _QuestionType.repeatAudio,
          word: word,
          options: const [],
          correctIndex: -1,
          prompt: repeatSentence
              ? 'استمع ثم كرر الجملة بالألمانية'
              : 'استمع ثم كرر الكلمة بالألمانية',
          voiceTarget: repeatSentence ? word.example : word.german,
        );
    }
  }

  List<WordModel> _audioMatchEligible(List<WordModel> words) {
    final result = <WordModel>[];
    final seenGerman = <String>{};
    final seenTranslation = <String>{};

    for (final word in words) {
      final german = word.german.trim();
      final translation = word.translation.trim();

      if (german.isEmpty || translation.isEmpty) continue;

      final germanKey = german.toLowerCase();
      final translationKey = translation.toLowerCase();

      if (!seenGerman.add(germanKey)) continue;
      if (!seenTranslation.add(translationKey)) continue;

      result.add(word);
    }

    return result;
  }

  _Question _buildAudioMatchQuestion(List<WordModel> words) {
    final eligible = _audioMatchEligible(words)..shuffle(_random);
    final selectedWords = eligible.take(4).toList();
    final translations =
        selectedWords.map((word) => word.translation.trim()).toList()
          ..shuffle(_random);

    return _Question(
      type: _QuestionType.audioMatch,
      word: selectedWords.first,
      options: const [],
      correctIndex: -1,
      prompt: 'استمع إلى الكلمات وطابق كل صوت مع ترجمته',
      matchingWords: selectedWords,
      matchingTranslations: translations,
    );
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


  bool _isVoiceQuestion(_Question question) {
    return question.type == _QuestionType.speakWord ||
        question.type == _QuestionType.speakSentence ||
        question.type == _QuestionType.repeatAudio;
  }

  Future<void> _speakVoicePrompt(_Question question) async {
    final target = question.voiceTarget?.trim();
    if (target == null || target.isEmpty) return;

    await _speech.speakGerman(
      target,
      activeKey: 'exercise-voice-prompt',
    );
  }

  Future<void> _startVoiceQuestion(_Question question) async {
    if (_voiceFinishing || _voiceAnswered) return;

    if (_voiceRecognition.isRecording) {
      await _finishVoiceQuestion(question);
      return;
    }

    await _speech.stop();
    _voiceTimer?.cancel();

    if (mounted) {
      setState(() {
        _voiceTranscript = null;
        _voiceCorrect = null;
      });
    }

    try {
      await _voiceRecognition.startListening(
        initialPrompt: 'Kurze deutsche Antwort. Nur Deutsch.',
      );

      if (!mounted) return;

      setState(() {});
      final seconds =
          question.type == _QuestionType.speakSentence ? 10 : 6;

      _voiceTimer = Timer(
        Duration(seconds: seconds),
        () => _finishVoiceQuestion(question),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تشغيل الميكروفون: ${e}')),
      );
    }
  }

  Future<void> _finishVoiceQuestion(_Question question) async {
    if (_voiceFinishing || !_voiceRecognition.isRecording) return;

    _voiceTimer?.cancel();
    _voiceFinishing = true;
    if (mounted) setState(() {});

    try {
      final result = await _voiceRecognition.stopListening();
      final transcript = result.text.trim();
      final target = question.voiceTarget?.trim() ?? '';
      final correct = SpeechAnswerEvaluator.matches(
        transcript,
        target,
        sentence: question.type == _QuestionType.speakSentence,
      );

      if (!mounted) return;

      setState(() {
        _voiceTranscript = transcript;
        _voiceCorrect = correct;
        _voiceAnswered = true;
        _voiceFinishing = false;
        _answered++;
        if (correct) {
          _score++;
          _streak++;
        } else {
          _streak = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _voiceFinishing = false;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحليل التسجيل: ${e}')),
      );
    }
  }

  Widget _voiceQuestionCard(_Question question) {
    final recording =
        _voiceRecognition.state.value == SpeechRecognitionState.recording;
    final preparing =
        _voiceRecognition.state.value == SpeechRecognitionState.preparing;
    final processing =
        _voiceRecognition.state.value == SpeechRecognitionState.processing;
    final error =
        _voiceRecognition.state.value == SpeechRecognitionState.error;

    final isAudioPrompt = question.type == _QuestionType.repeatAudio;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFE6E7F0)),
      ),
      child: Column(
        children: [
          Text(
            question.prompt ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          if (isAudioPrompt)
            ValueListenableBuilder<String?>(
              valueListenable: _speech.activeKey,
              builder: (context, activeKey, _) {
                final active = activeKey == 'exercise-voice-prompt';
                return FilledButton.icon(
                  onPressed: _voiceAnswered || recording || preparing ||
                          processing || _voiceFinishing
                      ? null
                      : () => _speakVoicePrompt(question),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                  ),
                  icon: Icon(
                    active ? Icons.volume_up_rounded : Icons.headphones_rounded,
                  ),
                  label: Text(active ? 'جاري التشغيل...' : 'استمع إلى النطق'),
                );
              },
            )
          else
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                question.content ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.45,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF171A2A),
                ),
              ),
            ),
          const SizedBox(height: 16),
          ValueListenableBuilder<SpeechRecognitionState>(
            valueListenable: _voiceRecognition.state,
            builder: (context, state, _) {
              final recording = state == SpeechRecognitionState.recording;
              final busy = state == SpeechRecognitionState.preparing ||
                  state == SpeechRecognitionState.processing ||
                  _voiceFinishing;

              final title = busy
                  ? state == SpeechRecognitionState.preparing
                      ? 'تهيئة التعرف على الألمانية'
                      : 'تحليل إجابتك...'
                  : recording
                      ? 'جاري التسجيل — اضغط للإيقاف'
                      : error
                          ? 'إعادة محاولة الميكروفون'
                          : '🎙️ ابدأ الإجابة';

              final icon = recording
                  ? Icons.stop_rounded
                  : busy
                      ? Icons.hourglass_top_rounded
                      : Icons.mic_rounded;

              return Column(
                children: [
                  FilledButton.icon(
                    onPressed: _voiceAnswered || busy
                        ? null
                        : () => _startVoiceQuestion(question),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor:
                          recording ? const Color(0xFFE45757) : null,
                    ),
                    icon: Icon(icon),
                    label: Text(title),
                  ),
                  if (state == SpeechRecognitionState.preparing)
                    ValueListenableBuilder<double>(
                      valueListenable: _voiceRecognition.downloadProgress,
                      builder: (context, progress, _) {
                        if (progress <= 0) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          if (recording)
            ValueListenableBuilder<String>(
              valueListenable: _voiceRecognition.liveText,
              builder: (context, text, _) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  text.trim().isEmpty
                      ? 'تحدث بالألمانية الآن...'
                      : text,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _voiceFeedback(_Question question) {
    final transcript = _voiceTranscript?.trim() ?? '';
    final correct = _voiceCorrect == true;
    final target = question.voiceTarget?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct
            ? const Color(0xFFE9F9F5)
            : const Color(0xFFFFECEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: correct
              ? const Color(0xFFB8E8DC)
              : const Color(0xFFF0B9C0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: correct
                    ? const Color(0xFF16A88F)
                    : const Color(0xFFE45757),
              ),
              const SizedBox(width: 7),
              Text(
                correct ? 'إجابة صوتية صحيحة' : 'إجابة صوتية غير صحيحة',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 11),
            const Text(
              'ما فهمه النظام',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              transcript,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'الإجابة الصحيحة',
            style: TextStyle(
              color: Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            target,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5B5FEF),
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _choose(int index) {
    if (_selected != null || _currentQuestion == null) return;
    if (_currentQuestion!.type == _QuestionType.audioMatch) return;

    final question = _currentQuestion!;
    final correct = index == question.correctIndex;

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

    _scheduleFeedbackSpeech(question, _questionGeneration);
  }

  Future<void> _next() async {
    if (_words.length < 2) return;

    // Invalidate any delayed speech belonging to the previous question.
    final nextGeneration = ++_questionGeneration;
    await _speech.stop();
    if (!mounted) return;

    final question = _makeQuestion(_words);

    setState(() {
      _currentQuestion = question;
      _selected = null;
      _selectedAudioIndex = null;
      _wrongAudioIndex = null;
      _wrongTranslationIndex = null;
      _matchedPairs.clear();
      _voiceTimer?.cancel();
      _voiceFinishing = false;
      _voiceAnswered = false;
      _voiceTranscript = null;
      _voiceCorrect = null;
    });

    _scheduleAutoQuestionSpeech(question, nextGeneration);
  }

  void _scheduleAutoQuestionSpeech(
    _Question question,
    int generation,
  ) {
    // The audio-matching exercise is intentionally silent until
    // the learner presses one of the audio cards.
    if (question.type == _QuestionType.audioMatch ||
        _isVoiceQuestion(question)) {
      return;
    }

    final content = question.content?.trim();
    if (content == null ||
        content.isEmpty ||
        !_questionContentIsGerman(question)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _selected != null ||
          generation != _questionGeneration ||
          _currentQuestion != question) {
        return;
      }

      _speech.speakGerman(
        content,
        activeKey: 'exercise-question',
        automaticKey: 'exercise-question-$_speechSessionId-$generation',
      );
    });
  }

  void _scheduleFeedbackSpeech(_Question question, int generation) {
    final sentence = question.word.example.trim();
    final word = question.word.german.trim();
    final content = sentence.isNotEmpty ? sentence : word;
    final key = sentence.isNotEmpty
        ? 'exercise-feedback-sentence'
        : 'exercise-feedback-word';

    if (content.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _selected == null ||
          generation != _questionGeneration ||
          _currentQuestion != question) {
        return;
      }

      _speech.speakGerman(
        content,
        activeKey: key,
        automaticKey: 'exercise-feedback-$_speechSessionId-$generation',
      );
    });
  }

  Future<void> _playAudioMatchWord(
    _Question question,
    int index,
  ) async {
    await _speech.speakGerman(
      question.matchingWords[index].german,
      activeKey: 'exercise-audio-match-$index',
    );
  }

  Future<void> _selectAudio(int index) async {
    final question = _currentQuestion;
    if (question == null ||
        question.type != _QuestionType.audioMatch ||
        _matchedPairs.containsKey(index)) {
      return;
    }

    setState(() {
      _selectedAudioIndex = index;
      _wrongAudioIndex = null;
      _wrongTranslationIndex = null;
    });

    await _playAudioMatchWord(question, index);
  }

  void _selectTranslation(int translationIndex) {
    final question = _currentQuestion;
    final audioIndex = _selectedAudioIndex;

    if (question == null ||
        question.type != _QuestionType.audioMatch ||
        audioIndex == null ||
        _matchedPairs.containsKey(audioIndex) ||
        _matchedPairs.containsValue(translationIndex)) {
      return;
    }

    final expected =
        question.matchingWords[audioIndex].translation.trim().toLowerCase();
    final chosen =
        question.matchingTranslations[translationIndex].trim().toLowerCase();

    if (expected == chosen) {
      setState(() {
        _matchedPairs[audioIndex] = translationIndex;
        _selectedAudioIndex = null;
        _wrongAudioIndex = null;
        _wrongTranslationIndex = null;
      });

      if (_matchedPairs.length == question.matchingWords.length) {
        setState(() {
          _answered++;
          _score++;
          _streak++;
        });
        return;
      }

      return;
    }

    setState(() {
      _wrongAudioIndex = audioIndex;
      _wrongTranslationIndex = translationIndex;
      _streak = 0;
    });

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;

      setState(() {
        _selectedAudioIndex = null;
        _wrongAudioIndex = null;
        _wrongTranslationIndex = null;
      });
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
      case _QuestionType.audioMatch:
        return 'استمع وطابق';
      case _QuestionType.speakWord:
        return 'ترجمة بصوتك';
      case _QuestionType.speakSentence:
        return 'تحدث بالجملة';
      case _QuestionType.repeatAudio:
        return 'استمع وكرر';
    }
  }

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
            if (q.type == _QuestionType.audioMatch) ...[
              _audioMatchQuestion(q),
              if (_matchedPairs.length == q.matchingWords.length) ...[
                const SizedBox(height: 12),
                _audioMatchComplete(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('السؤال التالي'),
                ),
              ],
            ] else if (_isVoiceQuestion(q)) ...[
              _voiceQuestionCard(q),
              if (_voiceAnswered) ...[
                _voiceFeedback(q),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('السؤال التالي'),
                ),
              ],
            ] else ...[
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
    final contentIsGerman = _questionContentIsGerman(q);

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
            textDirection: contentIsGerman ? TextDirection.ltr : TextDirection.rtl,
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
        q.type == _QuestionType.findSentence;
  }

  Widget _audioMatchQuestion(_Question q) {
    final matchedCount = _matchedPairs.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE6E7F0)),
      ),
      child: Column(
        children: [
          const Text(
            'استمع إلى الصوت ثم اختر الترجمة المناسبة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF171A2A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$matchedCount / ${q.matchingWords.length} أزواج صحيحة',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildMatchingTranslations(q)),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 260,
                  color: const Color(0xFFE6E7F0),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildMatchingAudio(q)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingAudio(_Question q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 9),
          child: Text(
            '🔊 الأصوات',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF171A2A),
            ),
          ),
        ),
        for (var i = 0; i < q.matchingWords.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _matchingAudioCard(q, i),
          ),
      ],
    );
  }

  Widget _matchingAudioCard(_Question q, int index) {
    final matched = _matchedPairs.containsKey(index);
    final selected = _selectedAudioIndex == index;
    final wrong = _wrongAudioIndex == index;

    return ValueListenableBuilder<String?>(
      valueListenable: _speech.activeKey,
      builder: (context, activeKey, _) {
        final speaking = activeKey == 'exercise-audio-match-$index';

        final background = wrong
            ? const Color(0xFFFFECEE)
            : matched
                ? const Color(0xFFE9F9F5)
                : selected
                    ? const Color(0xFFE9E8FF)
                    : const Color(0xFFF7F7FB);

        final border = wrong
            ? const Color(0xFFE95D6A)
            : matched
                ? const Color(0xFF16A88F)
                : selected
                    ? const Color(0xFF5B5FEF)
                    : const Color(0xFFE2E3EC);

        return Semantics(
          button: true,
          label: 'تشغيل الكلمة الألمانية',
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => matched
                  ? _playAudioMatchWord(q, index)
                  : _selectAudio(index),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 70,
                  minWidth: 70,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: border,
                    width: selected || wrong ? 1.7 : 1,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: AnimatedScale(
                        scale: speaking ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 160),
                        child: Icon(
                          speaking
                              ? Icons.volume_up_rounded
                              : Icons.volume_up_outlined,
                          color: matched
                              ? const Color(0xFF16A88F)
                              : const Color(0xFF5B5FEF),
                          size: 30,
                        ),
                      ),
                    ),
                    if (matched)
                      const PositionedDirectional(
                        top: -6,
                        end: -6,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: Color(0xFF16A88F),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    if (wrong)
                      const PositionedDirectional(
                        top: -6,
                        end: -6,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: Color(0xFFE95D6A),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchingTranslations(_Question q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 9),
          child: Text(
            'الترجمات',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF171A2A),
            ),
          ),
        ),
        for (var i = 0; i < q.matchingTranslations.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _matchingTranslationCard(q, i),
          ),
      ],
    );
  }

  Widget _matchingTranslationCard(_Question q, int index) {
    int? matchedAudioIndex;

    for (final entry in _matchedPairs.entries) {
      if (entry.value == index) {
        matchedAudioIndex = entry.key;
        break;
      }
    }

    final matched = matchedAudioIndex != null;
    final wrong = _wrongTranslationIndex == index;

    return Material(
      color: wrong
          ? const Color(0xFFFFECEE)
          : matched
              ? const Color(0xFFE9F9F5)
              : const Color(0xFFF7F7FB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: matched ? null : () => _selectTranslation(index),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: wrong
                  ? const Color(0xFFE95D6A)
                  : matched
                      ? const Color(0xFF16A88F)
                      : const Color(0xFFE2E3EC),
              width: wrong ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  q.matchingTranslations[index],
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (matched)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A88F),
                  size: 19,
                ),
              if (wrong)
                const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFE95D6A),
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audioMatchComplete() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F9F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8E8DC)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.celebration_rounded,
            color: Color(0xFF16A88F),
            size: 28,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'أحسنت! طابقت جميع الأصوات مع الترجمات الصحيحة.',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
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
