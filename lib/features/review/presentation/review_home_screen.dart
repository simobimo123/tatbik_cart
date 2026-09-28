import 'package:flutter/material.dart';

import '../../../data/models/category_model.dart';
import '../../../data/repositories/category_repository.dart';
import 'add_review_word_screen.dart';
import 'review_screen.dart';
import '../../export/presentation/export_words_screen.dart';

class ReviewHomeScreen extends StatefulWidget {
  const ReviewHomeScreen({super.key});

  @override
  State<ReviewHomeScreen> createState() => _ReviewHomeScreenState();
}

class _ReviewHomeScreenState extends State<ReviewHomeScreen> {
  final _categories = CategoryRepository();
  late Future<_ReviewOverview> _overview;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _overview = _loadOverview();
  }

  Future<_ReviewOverview> _loadOverview() async {
    final results = await Future.wait([
      _categories.reviewCount(),
      _categories.reviewDifficultyCounts(),
      _categories.getCategories(),
    ]);

    return _ReviewOverview(
      total: results[0] as int,
      difficulties: results[1] as Map<String, int>,
      categories: results[2] as List<CategoryModel>,
    );
  }

  Future<void> _openSession({int? categoryId, String? difficulty}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          categoryId: categoryId,
          difficulty: difficulty,
        ),
      ),
    );
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openAddWord() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddReviewWordScreen()),
    );
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openExport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExportWordsScreen()),
    );
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'حذف التصنيف؟',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          category.wordCount == 0
              ? 'سيتم حذف التصنيف «${category.name}».'
              : 'سيتم حذف التصنيف «${category.name}» وحذف جميع الكلمات المرتبطة به من قاعدة البيانات ومن نظام المراجعة. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE95D6A),
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await _categories.delete(category.id);
      if (!mounted) return;

      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف التصنيف «${category.name}»')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف التصنيف: $e')),
      );
    }
  }

  Future<void> _addCategory() async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );

    if (!mounted || draft == null || draft.name.trim().isEmpty) return;

    try {
      await _categories.create(
        draft.name,
        difficulty: draft.difficulty,
      );
      if (!mounted) return;

      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ التصنيف «${draft.name.trim()}»')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ التصنيف: $e')),
      );
    }
  }

  Future<void> _editCategoryDifficulty(CategoryModel category) async {
    final difficulty = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryDifficultyDialog(
        initialDifficulty: category.difficulty,
      ),
    );

    if (!mounted || difficulty == null) return;

    try {
      await _categories.updateDifficulty(category.id, difficulty);
      if (!mounted) return;
      setState(_refresh);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث مستوى التصنيف: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المراجعة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _openAddWord,
            tooltip: 'إضافة كلمة',
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: _openExport,
            tooltip: 'تصدير',
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: FutureBuilder<_ReviewOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر تحميل أقسام المراجعة:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(_refresh);
              await _overview;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                _header(data.total),
                const SizedBox(height: 18),
                _sectionTitle('جميع كلمات المراجعة'),
                const SizedBox(height: 9),
                _allCard(data.total),
                const SizedBox(height: 22),
                _sectionTitle('مستوى الصعوبة'),
                const SizedBox(height: 9),
                _difficultyGrid(data.difficulties),
                const SizedBox(height: 24),
                _sectionTitle('التصنيفات'),
                const SizedBox(height: 9),
                if (data.categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'لا توجد تصنيفات بعد. يمكنك إنشاء تصنيف فارغ الآن.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                else
                  ...data.categories.map(_categoryCard),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة تصنيف جديد'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكن أن يكون التصنيف فارغًا. عند إضافة كلمات إليه من JSON أو من شاشة الإضافة، سيظهر عددها هنا تلقائيًا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(int total) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B5FEF), Color(0xFF7567F8)],
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
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نظّم مراجعتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total كلمة في نظام المراجعة',
                  style: const TextStyle(color: Color(0xFFEDEEFF), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      );

  Widget _allCard(int total) {
    return _ReviewTile(
      icon: Icons.all_inclusive_rounded,
      title: 'جميع الكلمات',
      count: total,
      subtitle: 'ابدأ المراجعة دون فلترة',
      background: const Color(0xFFEEF0FF),
      onTap: () => _openSession(),
    );
  }

  Widget _difficultyGrid(Map<String, int> counts) {
    final items = [
      _DifficultyData('easy', 'سهل', 'كلمات شائعة جدًا في الحياة اليومية',
          Icons.sentiment_satisfied_alt_rounded, const Color(0xFFE9F9F5)),
      _DifficultyData('medium', 'متوسط', 'كلمات مستعملة لكن أقل رواجًا',
          Icons.sentiment_neutral_rounded, const Color(0xFFFFF4DF)),
      _DifficultyData('hard', 'صعب', 'كلمات مفيدة وأقل شيوعًا',
          Icons.sentiment_dissatisfied_rounded, const Color(0xFFFFECEE)),
      _DifficultyData('unspecified', 'غير محدد', 'كلمات لم تحدد صعوبتها بعد',
          Icons.help_outline_rounded, const Color(0xFFF1F2F6)),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < items.length ? 10 : 0),
            child: Row(
              children: [
                Expanded(child: _difficultyCard(items[i], counts[items[i].key] ?? 0)),
                const SizedBox(width: 10),
                Expanded(child: _difficultyCard(items[i + 1], counts[items[i + 1].key] ?? 0)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _difficultyCard(_DifficultyData item, int count) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: () => _openSession(difficulty: item.key),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE7E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.background,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    count.toString(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _difficultyLabel(String value) {
    switch (value) {
      case 'easy':
        return 'سهل';
      case 'medium':
        return 'متوسط';
      case 'hard':
        return 'صعب';
      default:
        return 'غير محدد';
    }
  }

  Widget _categoryCard(CategoryModel category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _ReviewTile(
        icon: Icons.folder_rounded,
        title: category.name,
        count: category.wordCount,
        subtitle: category.wordCount == 0
            ? 'تصنيف فارغ — أضف إليه كلمات لاحقًا • المستوى: ${_difficultyLabel(category.difficulty)}'
            : 'كلمات المراجعة • المستوى: ${_difficultyLabel(category.difficulty)}',
        background: const Color(0xFFF0EFFF),
        onTap: () => _openSession(categoryId: category.id),
        onEdit: () => _editCategoryDifficulty(category),
        onDelete: () => _deleteCategory(category),
      ),
    );
  }
}



class _CategoryDraft {
  const _CategoryDraft({
    required this.name,
    required this.difficulty,
  });

  final String name;
  final String difficulty;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _controller;
  String _difficulty = 'unspecified';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(
      _CategoryDraft(
        name: name,
        difficulty: _difficulty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'إضافة تصنيف جديد',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'اسم التصنيف',
              hintText: 'مثال: التسوق',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(
              labelText: 'مستوى المجموعة',
            ),
            items: const [
              DropdownMenuItem(
                value: 'easy',
                child: Text('سهل'),
              ),
              DropdownMenuItem(
                value: 'medium',
                child: Text('متوسط'),
              ),
              DropdownMenuItem(
                value: 'hard',
                child: Text('صعب'),
              ),
              DropdownMenuItem(
                value: 'unspecified',
                child: Text('غير محدد'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _difficulty = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _CategoryDifficultyDialog extends StatefulWidget {
  const _CategoryDifficultyDialog({
    required this.initialDifficulty,
  });

  final String initialDifficulty;

  @override
  State<_CategoryDifficultyDialog> createState() =>
      _CategoryDifficultyDialogState();
}

class _CategoryDifficultyDialogState
    extends State<_CategoryDifficultyDialog> {
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.initialDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'مستوى المجموعة',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: DropdownButtonFormField<String>(
        initialValue: _difficulty,
        items: const [
          DropdownMenuItem(value: 'easy', child: Text('سهل')),
          DropdownMenuItem(value: 'medium', child: Text('متوسط')),
          DropdownMenuItem(value: 'hard', child: Text('صعب')),
          DropdownMenuItem(value: 'unspecified', child: Text('غير محدد')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _difficulty = value);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_difficulty),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _ReviewOverview {
  const _ReviewOverview({
    required this.total,
    required this.difficulties,
    required this.categories,
  });

  final int total;
  final Map<String, int> difficulties;
  final List<CategoryModel> categories;
}

class _DifficultyData {
  const _DifficultyData(this.key, this.title, this.subtitle, this.icon, this.background);

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.subtitle,
    required this.background,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final int count;
  final String subtitle;
  final Color background;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE7E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFF5B5FEF)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                count.toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 5),
              if (onEdit != null) ...[
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'تغيير مستوى التصنيف',
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF5B5FEF),
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 2),
              ],
              if (onDelete != null) ...[
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'حذف التصنيف',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE95D6A),
                    size: 21,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 2),
              ],
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
