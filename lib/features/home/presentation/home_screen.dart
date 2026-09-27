import 'package:flutter/material.dart';
import '../../../data/repositories/word_repository.dart';
import '../../words/presentation/add_word_screen.dart';
import '../../words/presentation/library_screen.dart';
import '../../review/presentation/review_screen.dart';
import '../../exercises/presentation/exercise_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = WordRepository();

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Deutsch Lernen'), centerTitle: true),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('تعلم الألمانية بدون إنترنت', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('الكلمات والمراجعة والتمارين محفوظة بالكامل على الهاتف.'),
      const SizedBox(height: 20),
      FutureBuilder(future: Future.wait([_repository.count(), _repository.dueCount()]), builder: (context, snapshot) {
        final values = snapshot.data ?? [0, 0];
        return Row(children: [
          Expanded(child: _stat(Icons.menu_book, values[0].toString(), 'كلمة')),
          const SizedBox(width: 12),
          Expanded(child: _stat(Icons.refresh, values[1].toString(), 'للمراجعة')),
        ]);
      }),
      const SizedBox(height: 12),
      _action('مراجعة الكلمات', 'بطاقات: كشف ثم سحب يمين/يسار', Icons.style, () => _open(const ReviewScreen())),
      _action('قاموس الكلمات', 'بحث وتصفح وإضافة كلمات', Icons.search, () => _open(const LibraryScreen())),
      _action('التمارين', 'اختر الترجمة الصحيحة', Icons.quiz, () => _open(const ExerciseScreen())),
      _action('إضافة كلمة', 'أضف كلمة وترجمة ومثال', Icons.add_circle, () => _open(const AddWordScreen())),
    ]),
  );

  Widget _stat(IconData icon, String value, String label) => Card(child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(children: [Icon(icon), Text(value, style: Theme.of(context).textTheme.headlineMedium), Text(label)]),
  ));

  Widget _action(String title, String subtitle, IconData icon, VoidCallback onTap) => Card(child: ListTile(
    contentPadding: const EdgeInsets.all(12),
    leading: CircleAvatar(child: Icon(icon)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  ));
}
