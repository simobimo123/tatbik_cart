import 'package:flutter/material.dart';
import '../../../core/services/speech_service.dart';

class GermanReaderScreen extends StatefulWidget {
  const GermanReaderScreen({super.key});

  @override
  State<GermanReaderScreen> createState() => _GermanReaderScreenState();
}

class _GermanReaderScreenState extends State<GermanReaderScreen> {
  static const _primary = Color(0xFF5B5FEF);
  static const _background = Color(0xFFF7F8FC);
  static const _text = Color(0xFF171A2A);

  final _speech = SpeechService.instance;
  final TextEditingController _textController = TextEditingController();

  List<String> _sentences = [];
  int _readerGeneration = 0;

  @override
  void initState() {
    super.initState();
    _speech.initialize();
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  List<String> _splitSentences(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return [];

    return RegExp(r'[^.!?]+[.!?]+|[^.!?]+$')
        .allMatches(normalized)
        .map((match) => match.group(0)!.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();
  }

  List<String> _splitWords(String sentence) {
    return sentence
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  String _cleanWord(String word) {
    return word
        .replaceAll(RegExp(r'^[.,!?;:()„“”«»]+'), '')
        .replaceAll(RegExp(r'[.,!?;:()„“”«»]+$'), '')
        .trim();
  }

  Future<void> _speak(String value, String key) async {
    await _speech.speakGerman(
      value,
      activeKey: key,
    );
  }

  Future<void> _stopSpeaking() async {
    await _speech.stop();
  }

  void _showText() {
    final sentences = _splitSentences(_textController.text);
    FocusScope.of(context).unfocus();

    setState(() {
      _sentences = sentences;
      _readerGeneration++;
    });

    if (sentences.isNotEmpty) {
      final generation = _readerGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _speech.speakGerman(
          sentences.first,
          activeKey: 'reader-sentence-0',
          automaticKey: 'reader-$generation',
        );
      });
    }
  }

  Future<void> _clearText() async {
    await _stopSpeaking();
    if (!mounted) return;

    _textController.clear();

    setState(() {
      _sentences = [];
    });
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
          ValueListenableBuilder<bool>(
            valueListenable: _speech.speaking,
            builder: (context, speaking, _) {
              if (!speaking) return const SizedBox.shrink();

              return IconButton(
                onPressed: _stopSpeaking,
                tooltip: 'إيقاف الصوت',
                icon: const Icon(Icons.stop_circle_outlined),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildTextInput(),
          if (_sentences.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildReaderHeader(),
            const SizedBox(height: 12),
            for (var i = 0; i < _sentences.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildSentenceCard(_sentences[i], i),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF7567F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x225B5FEF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.record_voice_over_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'القارئ الألماني',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'استمع إلى الجملة أو انطق أي كلمة منفردة.',
                  style: TextStyle(
                    color: Color(0xFFEDEEFF),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'أدخل النص الألماني',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
              ),
              if (hasText)
                IconButton(
                  onPressed: _clearText,
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            minLines: 5,
            maxLines: 9,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText:
                  'Ich lerne Deutsch. Heute lese ich einen kurzen Text.',
              hintStyle: const TextStyle(
                color: Colors.black38,
                height: 1.5,
              ),
              alignLabelWithHint: true,
              filled: true,
              fillColor: const Color(0xFFFAFAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(15),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 11),
          FilledButton.icon(
            onPressed: hasText ? _showText : null,
            icon: const Icon(Icons.chrome_reader_mode_rounded),
            label: const Text('ابدأ القراءة'),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'النص',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_sentences.length} جملة',
            style: const TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceCard(String sentence, int index) {
    final sentenceKey = 'sentence-$index';
    final words = _splitWords(sentence);

    return ValueListenableBuilder<String?>(
      valueListenable: _speech.activeKey,
      builder: (context, activeKey, _) {
        final sentencePlaying = activeKey == sentenceKey;

        return Container(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: sentencePlaying
                  ? const Color(0xFFCBCBFF)
                  : const Color(0xFFE5E7EF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: sentencePlaying ? .08 : .035,
                ),
                blurRadius: sentencePlaying ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSentenceSpeaker(
                    sentence,
                    sentenceKey,
                    active: sentencePlaying,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F8),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            'Satz ${index + 1}',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sentence,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: _text,
                            fontSize: sentence.length > 65 ? 18 : 21,
                            height: 1.55,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(height: 1),
              ),
              const Row(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 17,
                    color: Colors.black45,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'الكلمات الألمانية',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 8,
                children: [
                  for (var wordIndex = 0;
                      wordIndex < words.length;
                      wordIndex++)
                    _buildWordButton(
                      words[wordIndex],
                      '$sentenceKey-word-$wordIndex',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSentenceSpeaker(
    String sentence,
    String key, {
    required bool active,
  }) {
    return Material(
      color: active ? const Color(0xFF4649CA) : _primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _speak(sentence, key),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(
            active ? Icons.volume_up_rounded : Icons.volume_up_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildWordButton(String rawWord, String key) {
    final word = _cleanWord(rawWord);
    if (word.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<String?>(
      valueListenable: _speech.activeKey,
      builder: (context, activeKey, _) {
        final active = activeKey == key;

        return Material(
          color: active
              ? const Color(0xFFE9E8FF)
              : const Color(0xFFF4F5F8),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: () => _speak(word, key),
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 7, 11, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active
                        ? Icons.volume_up_rounded
                        : Icons.volume_up_outlined,
                    size: 16,
                    color: _primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    word,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
