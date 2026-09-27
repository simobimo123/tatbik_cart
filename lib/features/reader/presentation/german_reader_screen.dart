import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class GermanReaderScreen extends StatefulWidget {
  const GermanReaderScreen({super.key});

  @override
  State<GermanReaderScreen> createState() => _GermanReaderScreenState();
}

class _GermanReaderScreenState extends State<GermanReaderScreen> {
  static const _primary = Color(0xFF5B5FEF);
  static const _background = Color(0xFFF7F8FC);

  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();

  List<String> _sentences = [];
  bool _ready = false;
  bool _speaking = false;
  String? _speakingKey;

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setQueueMode(0);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        if (!mounted) return;
        setState(() => _speaking = true);
      });
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _speakingKey = null;
        });
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _speakingKey = null;
        });
      });
      _tts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _speakingKey = null;
        });
      });

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ready = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تهيئة النطق الألماني: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _textController.dispose();
    super.dispose();
  }

  List<String> _splitSentences(String text) {
    final normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return [];

    final matches = RegExp(r'[^.!?]+[.!?]+|[^.!?]+$')
        .allMatches(normalized);

    return matches
        .map((match) => match.group(0)!.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();
  }

  List<String> _splitWords(String sentence) {
    return sentence
        .split(RegExp(r'\\s+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  Future<void> _speak(String text, String key) async {
    final value = text.trim();
    if (value.isEmpty || !_ready) return;

    try {
      await _tts.stop();
      if (!mounted) return;
      setState(() => _speakingKey = key);
      await _tts.speak(value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _speakingKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر نطق النص: $e')),
      );
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _speakingKey = null;
    });
  }

  void _showText() {
    final sentences = _splitSentences(_textController.text);
    FocusScope.of(context).unfocus();

    setState(() {
      _sentences = sentences;
      _speakingKey = null;
    });
  }

  Future<void> _clearText() async {
    await _stopSpeaking();
    if (!mounted) return;
    _textController.clear();
    setState(() => _sentences = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'القارئ الألماني',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_speaking)
            IconButton(
              onPressed: _stopSpeaking,
              tooltip: 'إيقاف الصوت',
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          _buildIntro(),
          const SizedBox(height: 14),
          _buildInputCard(),
          if (_sentences.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'النص الألماني',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_sentences.length} جملة',
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _sentences.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSentenceCard(_sentences[i], i),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF7567F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: const [
          BoxShadow(
            color: Color(0x225B5FEF),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.record_voice_over_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اقرأ الألمانية بصوت مسموع',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ضع نصًا ألمانيًا، ثم اضغط على 🔊 بجانب الجملة أو الكلمة.',
                  style: TextStyle(
                    color: Color(0xFFEDEEFF),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFE7E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'النص الألماني',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _textController,
            minLines: 5,
            maxLines: 9,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              hintText:
                  'Zum Beispiel: Ich lerne Deutsch. Heute lese ich einen kurzen Text.',
              hintStyle: TextStyle(
                color: Colors.black38,
                height: 1.4,
              ),
              alignLabelWithHint: true,
            ),
            onChanged: (_) {
              setState(() {
                _sentences = [];
              });
            },
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _ready ? _showText : null,
                  icon: const Icon(Icons.auto_stories_rounded),
                  label: const Text('عرض النص'),
                ),
              ),
              if (_textController.text.isNotEmpty) ...[
                const SizedBox(width: 9),
                IconButton(
                  onPressed: _clearText,
                  tooltip: 'مسح النص',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F1F6),
                    minimumSize: const Size(54, 54),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceCard(String sentence, int index) {
    final sentenceKey = 'sentence-$index';
    final sentencePlaying = _speakingKey == sentenceKey;
    final words = _splitWords(sentence);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _speakerButton(
                  onPressed: () => _speak(sentence, sentenceKey),
                  active: sentencePlaying,
                  size: 46,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    sentence,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.55,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text(
            'الكلمات',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var wordIndex = 0; wordIndex < words.length; wordIndex++)
                  _buildWordChip(
                    words[wordIndex],
                    '$sentenceKey-word-$wordIndex',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(String word, String key) {
    final clean = word.replaceAll(
      RegExp(r'^[.,!?;:()\\[\\]{}„“”«»]+|[.,!?;:()\\[\\]{}„“”«»]+$'),
      '',
    );
    if (clean.isEmpty) return const SizedBox.shrink();

    final playing = _speakingKey == key;

    return Material(
      color: playing ? const Color(0xFFEAE9FF) : const Color(0xFFF3F4F8),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => _speak(clean, key),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                size: 17,
                color: _primary,
              ),
              const SizedBox(width: 5),
              Text(
                word,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speakerButton({
    required VoidCallback onPressed,
    required bool active,
    required double size,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: active ? const Color(0xFF4649CA) : _primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Icon(
          active ? Icons.volume_up_rounded : Icons.volume_up_outlined,
          size: size * .46,
          color: Colors.white,
        ),
      ),
    );
  }
}
