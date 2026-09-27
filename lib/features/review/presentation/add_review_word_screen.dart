import 'package:flutter/material.dart';

import '../../../data/models/category_model.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/word_repository.dart';

class AddReviewWordScreen extends StatefulWidget {
  const AddReviewWordScreen({super.key});

  @override
  State<AddReviewWordScreen> createState() => _AddReviewWordScreenState();
}

class _AddReviewWordScreenState extends State<AddReviewWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = WordRepository();
  final _categories = CategoryRepository();

  final _german = TextEditingController();
  final _translation = TextEditingController();
  final _example = TextEditingController();
  final _exampleTranslation = TextEditingController();

  List<CategoryModel> _categoryList = [];
  String _difficulty = 'unspecified';
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _german.dispose();
    _translation.dispose();
    _example.dispose();
    _exampleTranslation.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await _categories.getCategories();
    if (!mounted) return;
    setState(() => _categoryList = categories);
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة تصنيف'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(labelText: 'اسم التصنيف'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null) return;
    final id = await _categories.create(name);
    await _loadCategories();
    if (!mounted) return;
    setState(() => _categoryId = id);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);

    try {
      await _repository.addToReview(
        german: _german.text,
        translation: _translation.text,
        example: _example.text,
        exampleTranslation: _exampleTranslation.text,
        difficulty: _difficulty,
        categoryId: _categoryId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الكلمة إلى المراجعة')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الكلمة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إضافة إلى المراجعة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0EFFF), Color(0xFFFFFFFF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE6E5F6)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.playlist_add_rounded, color: Color(0xFF5B5FEF), size: 30),
                    SizedBox(height: 11),
                    Text(
                      'كلمة خاصة بالمراجعة',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'هذه الكلمة ستدخل مباشرة إلى بطاقات المراجعة، ولن تضاف إلى قاعدة اكتشاف الكلمات.',
                      style: TextStyle(color: Colors.black54, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _field(
                controller: _german,
                label: 'الكلمة بالألمانية',
                icon: Icons.language_rounded,
                direction: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _translation,
                label: 'ترجمة الكلمة',
                icon: Icons.translate_rounded,
                direction: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _example,
                label: 'الجملة المثال بالألمانية',
                icon: Icons.format_quote_rounded,
                direction: TextDirection.ltr,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _exampleTranslation,
                label: 'ترجمة الجملة المثال',
                icon: Icons.subtitles_rounded,
                direction: TextDirection.rtl,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              _metadataCard(),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة إلى المراجعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metadataCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E6EF)),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(
              labelText: 'صعوبة الكلمة',
              prefixIcon: Icon(Icons.speed_rounded),
              border: InputBorder.none,
            ),
            items: const [
              DropdownMenuItem(
                value: 'easy',
                child: Text('سهل — شائع جدًا'),
              ),
              DropdownMenuItem(
                value: 'medium',
                child: Text('متوسط — مستعمل لكن أقل رواجًا'),
              ),
              DropdownMenuItem(
                value: 'hard',
                child: Text('صعب — مفيد وأقل شيوعًا'),
              ),
              DropdownMenuItem(
                value: 'unspecified',
                child: Text('غير محدد'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _difficulty = value);
            },
          ),
          const Divider(height: 1),
          Row(
            children: [
              const Icon(Icons.folder_rounded, color: Color(0xFF5B5FEF)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
                    border: InputBorder.none,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('بدون تصنيف'),
                    ),
                    ..._categoryList.map(
                      (category) => DropdownMenuItem<int?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ),
              IconButton(
                onPressed: _createCategory,
                tooltip: 'إضافة تصنيف',
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextDirection direction,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      textDirection: direction,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
