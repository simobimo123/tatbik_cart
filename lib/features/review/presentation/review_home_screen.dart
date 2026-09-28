import 'package:flutter/material.dart';

import 'add_review_word_screen.dart';
import 'review_screen.dart';
import '../../export/presentation/export_words_screen.dart';

class ReviewHomeScreen extends StatelessWidget {
  const ReviewHomeScreen({super.key});

  Future<void> _openSession(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReviewScreen(),
      ),
    );
  }

  Future<void> _openAddWord(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddReviewWordScreen(),
      ),
    );
  }

  Future<void> _openExport(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExportWordsScreen(),
      ),
    );
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
            onPressed: () => _openAddWord(context),
            tooltip: 'إضافة كلمة',
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: () => _openExport(context),
            tooltip: 'تصدير الكلمات',
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
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
            child: const Row(
              children: [
                Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نظام المراجعة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'راجع جميع الكلمات المستحقة وفق نظام التكرار، بدون تقسيم حسب المجموعة أو المستوى.',
                        style: TextStyle(
                          color: Color(0xFFEDEEFF),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _card(
            context,
            icon: Icons.play_arrow_rounded,
            title: 'ابدأ المراجعة',
            subtitle: 'الكلمات المستحقة الآن وفق نظام التكرار داخل جلسة المراجعة',
            background: const Color(0xFFE9F9F5),
            onTap: () => _openSession(context),
          ),
          _card(
            context,
            icon: Icons.playlist_add_rounded,
            title: 'إضافة كلمة للمراجعة',
            subtitle: 'أضف كلمة مباشرة إلى المراجعة دون إضافتها إلى الاكتشاف',
            background: const Color(0xFFFFF3E8),
            onTap: () => _openAddWord(context),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF5B5FEF),
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المجموعات ومستوياتها مخصصة لاكتشاف الكلمات. في المراجعة لا توجد فلاتر للمجموعة أو مستوى الكلمة.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE7E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF5B5FEF),
                    size: 27,
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
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.4,
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
