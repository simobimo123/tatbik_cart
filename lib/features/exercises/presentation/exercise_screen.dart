import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/word_repository.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});
  @override State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final _repository = WordRepository();
  List<WordModel> _words = [];
  WordModel? _question;
  List<String> _options = [];
  String? _selected;
  int _score = 0;

  @override
  void initState() { super.initState(); _start(); }

  Future<void> _start() async {
    _words = await _repository.getWords();
    if (_words.length >= 4) _next();
    else if (mounted) setState(() {});
  }

  void _next() {
    if (_words.length < 4) return;
    _words.shuffle();
    _question = _words.first;
    final options = <String>{_question!.translation};
    for (final word in _words) {
      if (options.length >= 4) break;
      options.add(word.translation);
    }
    _options = options.toList()..shuffle();
    setState(() => _selected = null);
  }

  void _choose(String option) {
    if (_selected != null) return;
    setState(() {
      _selected = option;
      if (option == _question!.translation) _score++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('التمارين')),
        body: Center(child: Text(_words.length < 4 ? 'أضف أو حمّل أربع كلمات على الأقل.' : 'جاري التحميل...')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('التمارين', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(child: Text('$_score نقطة', style: const TextStyle(fontWeight: FontWeight.w700))),
        )],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: const Color(0xFFE9F9F5), borderRadius: BorderRadius.circular(24)),
            child: const Row(children: [
              Icon(Icons.lightbulb_rounded, color: Color(0xFF16A88F)),
              SizedBox(width: 10),
              Expanded(child: Text('اختر الترجمة الصحيحة للكلمة الظاهرة.', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 16),
          Card(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
            child: Column(children: [
              const Icon(Icons.quiz_rounded, color: Color(0xFF5B5FEF), size: 30),
              const SizedBox(height: 18),
              Text(_question!.german, textDirection: TextDirection.ltr, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          )),
          const SizedBox(height: 18),
          ..._options.asMap().entries.map((entry) {
            final option = entry.value;
            final correct = _selected != null && option == _question!.translation;
            final wrong = _selected == option && option != _question!.translation;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: correct ? const Color(0xFFE9F9F5) : wrong ? const Color(0xFFFFECEE) : Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: correct ? const Color(0xFF16A88F) : wrong ? const Color(0xFFE95D6A) : const Color(0xFFE2E3EC)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => _choose(option),
                  child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                    Container(width: 34, height: 34, alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFF0F1F7), borderRadius: BorderRadius.circular(10)),
                      child: Text(String.fromCharCode(65 + entry.key), style: const TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(option, textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    if (correct) const Icon(Icons.check_circle_rounded, color: Color(0xFF16A88F)),
                    if (wrong) const Icon(Icons.cancel_rounded, color: Color(0xFFE95D6A)),
                  ])),
                ),
              ),
            );
          }),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _next, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('السؤال التالي')),
          ],
        ],
      ),
    );
  }
}
