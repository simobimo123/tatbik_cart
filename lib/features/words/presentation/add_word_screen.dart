import 'package:flutter/material.dart';
import '../../../data/repositories/word_repository.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});
  @override State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _german = TextEditingController();
  final _translation = TextEditingController();
  final _example = TextEditingController();
  final _repository = WordRepository();

  @override
  void dispose() {
    _german.dispose();
    _translation.dispose();
    _example.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_german.text.trim().isEmpty || _translation.text.trim().isEmpty || _example.text.trim().isEmpty) return;
    await _repository.add(german: _german.text, translation: _translation.text, example: _example.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إضافة كلمة')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      TextField(controller: _german, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الكلمة بالألمانية')),
      const SizedBox(height: 12),
      TextField(controller: _translation, decoration: const InputDecoration(labelText: 'المعنى بالعربية')),
      const SizedBox(height: 12),
      TextField(controller: _example, textDirection: TextDirection.ltr, maxLines: 3, decoration: const InputDecoration(labelText: 'مثال بالألمانية')),
      const SizedBox(height: 20),
      FilledButton(onPressed: _save, child: const Text('حفظ محليًا')),
    ]),
  );
}
