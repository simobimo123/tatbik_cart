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

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'إضافة تصنيف جديد',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'اسم التصنيف',
            hintText: 'مثال: التسوق',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    try {
      await _categories.create(name);
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء التصنيف «' + name.trim() + '»')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء التصنيف: ' + e.toString())),
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
                  'تعذر تحميل أقسام المراجعة:\n' + snapshot.error.toString(),
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
                  total.toString() + ' كلمة في نظام المراجعة',
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

  Widget _categoryCard(CategoryModel category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _ReviewTile(
        icon: Icons.folder_rounded,
        title: category.name,
        count: category.wordCount,
        subtitle: category.wordCount == 0
            ? 'تصنيف فارغ — أضف إليه كلمات لاحقًا'
            : 'كلمات المراجعة في هذا التصنيف',
        background: const Color(0xFFF0EFFF),
        onTap: () => _openSession(categoryId: category.id),
      ),
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
  });

  final IconData icon;
  final String title;
  final int count;
  final String subtitle;
  final Color background;
  final VoidCallback onTap;

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
              const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
