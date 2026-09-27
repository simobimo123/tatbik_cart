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
    _german.dispose(); _translation.dispose(); _example.dispose(); super.dispose();
  }

  Future<void> _save() async {
    if (_german.text.trim().isEmpty || _translation.text.trim().isEmpty || _example.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل الحقول الثلاثة أولًا')));
      return;
    }
    await _repository.add(
      german: _german.text.trim(),
      translation: _translation.text.trim(),
      example: _example.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إضافة كلمة'), leading: const BackButton()),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFEEF0FF), Color(0xFFF5F2FF)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF5B5FEF), size: 30),
            SizedBox(height: 10),
            Text('أضف كلمة جديدة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text('احفظ الكلمة مع معناها ومثال يساعدك على تذكرها.',
                style: TextStyle(color: Colors.black54, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 22),
        _field(_german, 'الكلمة بالألمانية', Icons.language_rounded, TextDirection.ltr),
        const SizedBox(height: 12),
        _field(_translation, 'المعنى بالعربية', Icons.translate_rounded, TextDirection.rtl),
        const SizedBox(height: 12),
        TextField(
          controller: _example, textDirection: TextDirection.ltr, maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'مثال بالألمانية', alignLabelWithHint: true,
            prefixIcon: Icon(Icons.format_quote_rounded),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('حفظ الكلمة')),
      ],
    ),
  );

  Widget _field(TextEditingController controller, String label, IconData icon, TextDirection direction) =>
      TextField(controller: controller, textDirection: direction,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));
}
