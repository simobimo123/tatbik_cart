import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../data/repositories/word_import_repository.dart';

class ImportWordsScreen extends StatefulWidget {
  const ImportWordsScreen({super.key});
  @override State<ImportWordsScreen> createState() => _ImportWordsScreenState();
}

class _ImportWordsScreenState extends State<ImportWordsScreen> {
  final _repository = WordImportRepository();
  bool _busy = false;
  String? _fileName;

  Future<void> _import(WordImportTarget target) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);
      final result = await _repository.importJson(content, target: target);

      if (!mounted) return;
      setState(() => _fileName = file.name);

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اكتمل التصدير', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            'الملف: ${file.name}\n\n'
            'العناصر الصالحة: ${result.total}\n'
            'تمت إضافتها: ${result.added}\n'
            'تم تجاوزها: ${result.skipped}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      await _showError('ملف غير صالح', e.message);
    } catch (e) {
      if (!mounted) return;
      await _showError(
        'تعذر التصدير',
        'حدث خطأ أثناء قراءة الملف:\n\n$e',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showError(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد الكلمات', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF0EFFF), Color(0xFFFFFFFF)]),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE6E5F6)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.file_download_rounded, color: Color(0xFF5B5FEF), size: 32),
                SizedBox(height: 12),
                Text('استيراد ملف الكلمات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 7),
                Text(
                  'اختر ملف JSON من الهاتف ثم حدد المكان الذي تريد وضع الكلمات فيه.',
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_fileName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE6E7F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Color(0xFF5B5FEF)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_fileName!, style: const TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          _option(
            icon: Icons.explore_rounded,
            title: 'إضافة إلى اكتشاف الكلمات',
            subtitle: 'تدخل الكلمات إلى قاعدة الاكتشاف، ثم يحدد المستخدم إن كان يعرفها.',
            color: const Color(0xFF5B5FEF),
            onTap: () => _import(WordImportTarget.discovery),
          ),
          _option(
            icon: Icons.school_rounded,
            title: 'إضافة مباشرة إلى المراجعة',
            subtitle: 'تدخل الكلمات مباشرة إلى بطاقات المراجعة دون المرور بالاكتشاف.',
            color: const Color(0xFF16A88F),
            onTap: () => _import(WordImportTarget.review),
          ),
          const SizedBox(height: 8),
          const Text(
            'الصيغة: german + translation + example + example_translation + difficulty + category + category_difficulty',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}