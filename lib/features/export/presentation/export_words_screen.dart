import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/repositories/word_export_repository.dart';
import '../../import/presentation/import_words_screen.dart';

class ExportWordsScreen extends StatefulWidget {
  const ExportWordsScreen({super.key});

  @override
  State<ExportWordsScreen> createState() => _ExportWordsScreenState();
}

class _ExportWordsScreenState extends State<ExportWordsScreen> {
  final _repository = WordExportRepository();
  bool _busy = false;

  Future<void> _export({required bool reviewOnly}) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final json = await _repository.buildJson(reviewOnly: reviewOnly);
      final directory = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final kind = reviewOnly ? 'review' : 'all';
      final file = File(
        '${directory.path}/deutsch_lernen_${kind}_$stamp.json',
      );

      await file.writeAsString(json);

      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'استيراد كلمات الألمانية',
          subject: 'Deutsch Lernen - $kind',
          text: reviewOnly
              ? 'ملف كلمات المراجعة من تطبيق Deutsch Lernen'
              : 'ملف قاعدة الكلمات من تطبيق Deutsch Lernen',
          files: [
            XFile(
              file.path,
              mimeType: 'application/json',
              name: file.uri.pathSegments.last,
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (result.status != ShareResultStatus.dismissed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء الملف: ${file.uri.pathSegments.last}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء ملف الاستيراد: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'استيراد الكلمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0EFFF), Color(0xFFFFFFFF)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.file_upload_rounded,
                  color: Color(0xFF5B5FEF),
                  size: 31,
                ),
                SizedBox(height: 11),
                Text(
                  'احتفظ بقاعدة كلماتك',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'يُنشئ التطبيق ملف JSON يحتوي على الكلمة والترجمة والجملة وترجمة الجملة، ويمكنك حفظه أو مشاركته.',
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _option(
            icon: Icons.file_download_rounded,
            title: 'تصدير ملف JSON',
            subtitle: 'أدخل مجموعة كلمات إلى الاكتشاف أو المراجعة مباشرة',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ImportWordsScreen(),
                ),
              );
            },
          ),
          _option(
            icon: Icons.file_upload_rounded,
            title: 'استيراد كل الكلمات',
            subtitle: 'استيراد قاعدة الكلمات كاملة من ملف JSON',
            onTap: () => _export(reviewOnly: false),
          ),
          _option(
            icon: Icons.file_upload_rounded,
            title: 'استيراد كلمات المراجعة',
            subtitle: 'استيراد كلمات المراجعة من ملف JSON',
            onTap: () => _export(reviewOnly: true),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
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
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0FF),
                    borderRadius: BorderRadius.circular(16),
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.35,
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
