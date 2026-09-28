import 'package:flutter/material.dart';
import '../../../core/services/speech_service.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/discovery_repository.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _repository = DiscoveryRepository();
  final _categories = CategoryRepository();
  final _speech = SpeechService.instance;

  WordModel? _word;
  int _available = 0;
  List<CategoryModel> _categoryList = [];
  int? _selectedCategoryId;
  String? _selectedGroupDifficulty;
  bool _loading = true;
  bool _busy = false;
  bool _showMeaning = false;
  bool _isDragging = false;
  int _displayGeneration = 0;

  double _dragDx = 0;

  static const _primary = Color(0xFF5B5FEF);
  static const _green = Color(0xFF16A88F);
  static const _red = Color(0xFFE45757);

  @override
  void initState() {
    super.initState();
    _speech.initialize();
    _load(refreshCategories: true);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _load({bool refreshCategories = false}) async {
    if (refreshCategories) {
      _categoryList = await _categories.getCategories();
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _showMeaning = false;
      });
    }

    final word = await _repository.nextWord(
      categoryId: _selectedCategoryId,
      groupDifficulty: _selectedGroupDifficulty,
    );
    final available = await _repository.availableCount(
      categoryId: _selectedCategoryId,
      groupDifficulty: _selectedGroupDifficulty,
    );

    if (!mounted) return;

    setState(() {
      _word = word;
      _available = available;
      _loading = false;
      _busy = false;
      _showMeaning = false;
      _dragDx = 0;
      _isDragging = false;
      _displayGeneration++;
    });

    if (word != null) {
      final automaticKey = 'discovery-' + _displayGeneration.toString() + '-' + word.id.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _busy) return;
        _speech.speakGerman(
          word.german,
          activeKey: 'discovery-word-' + word.id.toString(),
          automaticKey: automaticKey,
        );
      });
    }
  }
  Future<void> _answer(bool known) async {
    final word = _word;
    if (word == null || _busy) return;

    setState(() {
      _busy = true;
      _showMeaning = !known;
    });

    await _repository.answer(word, known: known);

    if (!mounted) return;

    await Future.delayed(
      Duration(milliseconds: known ? 180 : 650),
    );

    if (!mounted) return;
    await _load(refreshCategories: true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_busy || _word == null) return;

    setState(() {
      _isDragging = true;
      _dragDx = (_dragDx + details.delta.dx).clamp(-260.0, 260.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_busy || _word == null) return;

    final velocity = details.primaryVelocity ?? 0;

    if (_dragDx > 145 || velocity > 1500) {
      _answer(true);
    } else if (_dragDx < -145 || velocity < -1500) {
      _answer(false);
    } else {
      setState(() {
        _dragDx = 0;
        _isDragging = false;
      });
    }
  }

  Widget _buildSpeaker(WordModel word) {
    return ValueListenableBuilder<String?>(
      valueListenable: _speech.activeKey,
      builder: (context, activeKey, _) {
        final active = activeKey == 'discovery-word-${word.id}';

        return Material(
          color: active
              ? const Color(0xFFE9E8FF)
              : const Color(0xFFF0F1F7),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _speech.speakGerman(
              word.german,
              activeKey: 'discovery-word-${word.id}',
            ),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                active
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                color: _primary,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اكتشاف الكلمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _addDiscoveryCategory,
            tooltip: 'إضافة مجموعة',
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          _discoveryFilterButton(),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE9E8FF), Color(0xFFF3F2FF)],
                  ),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 50,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'لا توجد كلمات متاحة الآن',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'أضف كلمات جديدة إلى ملف قاعدة الكلمات، وستظهر تلقائيًا في الاكتشاف.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _difficultyLabel(String? value) {
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

  Future<void> _addDiscoveryCategory() async {
    final controller = TextEditingController();
    var difficulty = 'unspecified';

    final draft = await showDialog<_DiscoveryCategoryDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مجموعة للاكتشاف', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'اسم المجموعة / الموضوع',
                  hintText: 'مثال: الحياة اليومية',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                decoration: const InputDecoration(labelText: 'مستوى المجموعة'),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('سهل')),
                  DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                  DropdownMenuItem(value: 'hard', child: Text('صعب')),
                  DropdownMenuItem(value: 'unspecified', child: Text('غير محدد')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => difficulty = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop(
                  _DiscoveryCategoryDraft(name: name, difficulty: difficulty),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (!mounted || draft == null) return;

    try {
      final id = await _categories.create(draft.name, difficulty: draft.difficulty);
      _categoryList = await _categories.getCategories();
      _selectedCategoryId = id;
      if (mounted) await _load(refreshCategories: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ المجموعة: ' + e.toString())),
      );
    }
  }

  Future<void> _editDiscoveryCategory(CategoryModel category) async {
    final difficulty = await showDialog<String>(
      context: context,
      builder: (_) => _DiscoveryCategoryDifficultyDialog(
        initialDifficulty: category.difficulty,
      ),
    );
    if (!mounted || difficulty == null) return;
    try {
      await _categories.updateDifficulty(category.id, difficulty);
      _categoryList = await _categories.getCategories();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث المجموعة: ' + e.toString())),
      );
    }
  }

  Future<void> _deleteDiscoveryCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المجموعة؟', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          category.wordCount == 0
              ? 'سيتم حذف المجموعة «' + category.name + '».',
              : 'سيتم حذف المجموعة «' + category.name + '» وحذف الكلمات المرتبطة بها. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _categories.delete(category.id);
      _categoryList = await _categories.getCategories();
      if (_selectedCategoryId == category.id) _selectedCategoryId = null;
      await _load(refreshCategories: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف المجموعة: ' + e.toString())),
      );
    }
  }

  Future<void> _showDiscoveryFilters() async {
    var categoryId = _selectedCategoryId;
    var groupDifficulty = _selectedGroupDifficulty;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('فلترة الاكتشاف', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: categoryId ?? -1,
                decoration: const InputDecoration(
                  labelText: 'الموضوع / المجموعة',
                  prefixIcon: Icon(Icons.folder_rounded),
                ),
                items: [
                  const DropdownMenuItem<int>(value: -1, child: Text('كل المجموعات')),
                  ..._categoryList.map(
                    (category) => DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(
                        category.name + ' • ' + _difficultyLabel(category.difficulty) + ' • ' + category.wordCount.toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setDialogState(() => categoryId = value == -1 ? null : value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: groupDifficulty ?? 'all',
                decoration: const InputDecoration(
                  labelText: 'مستوى المجموعة',
                  prefixIcon: Icon(Icons.speed_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل المستويات')),
                  DropdownMenuItem(value: 'easy', child: Text('سهل')),
                  DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                  DropdownMenuItem(value: 'hard', child: Text('صعب')),
                  DropdownMenuItem(value: 'unspecified', child: Text('غير محدد')),
                ],
                onChanged: (value) => setDialogState(() => groupDifficulty = value == 'all' ? null : value),
              ),
            ],
          ),
          actions: [
            if (categoryId != null) ...[
              TextButton.icon(
                onPressed: () async {
                  final category = _categoryList.firstWhere((item) => item.id == categoryId);
                  Navigator.of(dialogContext).pop();
                  await _editDiscoveryCategory(category);
                },
                icon: const Icon(Icons.tune_rounded),
                label: const Text('تعديل المجموعة'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final category = _categoryList.firstWhere((item) => item.id == categoryId);
                  Navigator.of(dialogContext).pop();
                  await _deleteDiscoveryCategory(category);
                },
                icon: const Icon(Icons.delete_outline_rounded, color: _red),
                label: const Text('حذف'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                await _speech.stop();
                _selectedCategoryId = categoryId;
                _selectedGroupDifficulty = groupDifficulty;
                await _load(refreshCategories: false);
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discoveryFilterButton() {
    final active = _selectedCategoryId != null || _selectedGroupDifficulty != null;
    return IconButton(
      onPressed: _showDiscoveryFilters,
      tooltip: active ? 'تغيير فلترة الاكتشاف' : 'فلترة الاكتشاف',
      icon: Icon(active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('اكتشاف الكلمات'),
          actions: [
            IconButton(
              onPressed: _addDiscoveryCategory,
              tooltip: 'إضافة مجموعة',
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            _discoveryFilterButton(),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final word = _word;
    if (word == null) {
      return _buildEmptyState();
    }

    final dragProgress = (_dragDx.abs() / 160).clamp(0.0, 1.0);
    final isKnownDrag = _dragDx > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'اكتشاف الكلمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [_discoveryFilterButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'هل تعرف هذه الكلمة؟',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الكلمات المعروفة تُحفظ في نهاية طابور الاكتشاف.',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE8E9F2),
                    ),
                  ),
                  child: Text(
                    '$_available متاحة',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onDoubleTap: () {
                if (_busy || _word == null) return;
                setState(() => _showMeaning = true);
              },
              onPanUpdate: _handleDragUpdate,
              onPanEnd: _handleDragEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..translateByDouble(_dragDx, 0.0, 0.0, 1.0)
                  ..rotateZ(_dragDx * 0.00065),
                transformAlignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 465),
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isDragging
                        ? (isKnownDrag
                            ? _green.withValues(alpha: 0.5)
                            : _red.withValues(alpha: 0.5))
                        : const Color(0xFFE8E9F2),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: 1 + dragProgress * 0.035,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFECEBFF), Color(0xFFF4F2FF)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: _primary,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Deutsch',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            word.german,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.7,
                                ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        _buildSpeaker(word),
                      ],
                    ),
                    const SizedBox(height: 13),
                    if (_showMeaning) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'المعنى',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              word.translation,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              word.example,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                height: 1.5,
                                fontSize: 13,
                              ),
                            ),
                            if (word.exampleTranslation.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                word.exampleTranslation,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  height: 1.45,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Text(
                        'اضغط مرتين لعرض الترجمة والتأكد من الكلمة',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ثم اختر «أعرفها» أو «لا أعرفها»',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (_isDragging) ...[
                      const SizedBox(height: 20),
                      AnimatedOpacity(
                        opacity: dragProgress,
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isKnownDrag
                                ? _green.withValues(alpha: 0.95)
                                : _red.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            isKnownDrag ? 'أعرفها' : 'لا أعرفها',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _answer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(
                        color: _red,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('لا أعرفها'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _answer(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('أعرفها'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            const Text(
              '«أعرفها» تنقل الكلمة إلى آخر طابور الاكتشاف. «لا أعرفها» تنقلها مباشرة إلى المراجعة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryCategoryDraft {
  const _DiscoveryCategoryDraft({required this.name, required this.difficulty});
  final String name;
  final String difficulty;
}

class _DiscoveryCategoryDifficultyDialog extends StatelessWidget {
  const _DiscoveryCategoryDifficultyDialog({required this.initialDifficulty});
  final String initialDifficulty;

class _DiscoveryCategoryDraft {
  const _DiscoveryCategoryDraft({
    required this.name,
    required this.difficulty,
  });

  final String name;
  final String difficulty;
}

class _DiscoveryCategoryDifficultyDialog extends StatefulWidget {
  const _DiscoveryCategoryDifficultyDialog({
    required this.initialDifficulty,
  });

  final String initialDifficulty;

  @override
  State<_DiscoveryCategoryDifficultyDialog> createState() =>
      _DiscoveryCategoryDifficultyDialogState();
}

class _DiscoveryCategoryDifficultyDialogState
    extends State<_DiscoveryCategoryDifficultyDialog> {
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
          if (value != null) setState(() => _difficulty = value);
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

