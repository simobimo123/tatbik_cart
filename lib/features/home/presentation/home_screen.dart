import 'package:flutter/material.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../review/presentation/review_home_screen.dart';
import '../../review/presentation/add_review_word_screen.dart';
import '../../words/presentation/library_screen.dart';
import '../../exercises/presentation/exercise_screen.dart';
import '../../discovery/presentation/discovery_screen.dart';
import '../../export/presentation/export_words_screen.dart';
import '../../import/presentation/import_words_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _wordRepository = WordRepository();
  final _discoveryRepository = DiscoveryRepository();

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => page,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .035),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B5FEF), Color(0xFF7B61FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deutsch Lernen',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'تعلم الألمانية بطريقة ذكية',
                        style: text.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _open(const AddReviewWordScreen()),
                  tooltip: 'إضافة إلى المراجعة',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B5FEF), Color(0xFF7567F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x225B5FEF),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'جاهز للتعلم؟',
                    style: text.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'اكتشف كلمات جديدة، ثم راجع فقط الكلمات التي تحتاج إلى تدريب.',
                    style: TextStyle(
                      color: Color(0xFFEDEEFF),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _open(const ReviewHomeScreen()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5B5FEF),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('ابدأ المراجعة'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<int>>(
              future: Future.wait([
                _wordRepository.count(),
                _wordRepository.dueCount(),
              ]),
              builder: (context, snapshot) {
                final values = snapshot.data ?? [0, 0];

                return Row(
                  children: [
                    Expanded(
                      child: _stat(
                        Icons.menu_book_rounded,
                        values[0].toString(),
                        'إجمالي الكلمات',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _stat(
                        Icons.schedule_rounded,
                        values[1].toString(),
                        'جاهزة للمراجعة',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            FutureBuilder<int>(
              future: _discoveryRepository.availableCount(),
              builder: (context, snapshot) {
                final available = snapshot.data ?? 0;

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  child: InkWell(
                    onTap: () => _open(const DiscoveryScreen()),
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFFE7E8F5),
                        ),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF4F3FF), Color(0xFFFFFFFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7E5FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.explore_rounded,
                              color: Color(0xFF5B5FEF),
                              size: 29,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اكتشاف الكلمات',
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'اعرف الكلمات التي تتقنها، وأرسل غير المعروفة إلى المراجعة.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  available == 0
                                      ? 'لا توجد كلمات متاحة الآن'
                                      : '$available كلمة متاحة الآن',
                                  style: const TextStyle(
                                    color: Color(0xFF5B5FEF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 17,
                            color: Colors.black38,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'أدوات التعلم',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _action(
              'المراجعة',
              'راجع الكلمات المستحقة وفق نظام التكرار',
              Icons.school_rounded,
              const Color(0xFFE9F9F5),
              () => _open(const ReviewScreen()),
            ),
            _action(
              'إضافة إلى المراجعة',
              'أضف كلمة بنفسك إلى بطاقات المراجعة',
              Icons.playlist_add_rounded,
              const Color(0xFFFFF3E8),
              () => _open(const AddReviewWordScreen()),
            ),
            _action(
              'قاعدة الكلمات',
              'تصفح قاعدة الكلمات والبحث فيها',
              Icons.menu_book_rounded,
              const Color(0xFFEEF0FF),
              () => _open(const LibraryScreen()),
            ),
            _action(
              'الاستيراد',
              'أدخل ملف JSON إلى الاكتشاف أو المراجعة مباشرة',
              Icons.file_upload_rounded,
              const Color(0xFFFFF3E8),
              () => _open(const ImportWordsScreen()),
            ),
            _action(
              'التصدير',
              'صدّر الكلمات والجمل والترجمات في ملف JSON',
              Icons.file_download_rounded,
              const Color(0xFFEFF0FF),
              () => _open(const ExportWordsScreen()),
            ),
            _action(
              'التمارين',
              'اختبر نفسك بطريقة تفاعلية',
              Icons.extension_rounded,
              const Color(0xFFE9F9F5),
              () => _open(const ExerciseScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 17,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9EAF2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF5B5FEF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    String title,
    String subtitle,
    IconData icon,
    Color background,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF5B5FEF),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
