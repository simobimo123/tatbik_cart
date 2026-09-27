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
    if (_words.length >= 4) {
      _next();
    } else if (mounted) {
      setState(() {});
    }
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
      appBar: AppBar(title: Text('التمارين • النقاط ' + _score.toString())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('اختر الترجمة الصحيحة', textAlign: TextAlign.center),
          const SizedBox(height: 25),
          Card(child: Padding(
            padding: const EdgeInsets.all(30),
            child: Text(
              _question!.german,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          )),
          const SizedBox(height: 20),
          ..._options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => _choose(option),
              child: Padding(padding: const EdgeInsets.all(12), child: Text(option, textAlign: TextAlign.center)),
            ),
          )),
          if (_selected != null) ...[
            const SizedBox(height: 10),
            Text(
              _selected == _question!.translation
                  ? 'إجابة صحيحة ✓'
                  : 'الإجابة الصحيحة: ' + _question!.translation,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _next, child: const Text('السؤال التالي')),
          ],
        ],
      ),
    );
  }
}
