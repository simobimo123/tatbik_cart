import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/word_repository.dart';
import '../../export/presentation/export_words_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  final _repository = WordRepository();
  List<WordModel> _data = [];

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_load);
  }

  @override
  void dispose() {
    _search.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _repository.getWords(_search.text);
    if (mounted) {
      setState(() => _data = data);
    }
  }

  Future<void> _openExport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExportWordsScreen(),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'قاعدة الكلمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _openExport,
            tooltip: 'استيراد الكلمات',
            icon: const Icon(Icons.file_upload_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: TextField(
              controller: _search,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'ابحث بالألمانية أو العربية',
              ),
            ),
          ),
          Expanded(
            child: _data.isEmpty
                ? const Center(
                    child: Text('لا توجد كلمات مطابقة'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _data.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final word = _data[index];

                      return Dismissible(
                        key: ValueKey(word.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _repository.remove(word.id),
                        background: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE95D6A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.all(20),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF0FF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    word.builtin
                                        ? Icons.auto_stories_rounded
                                        : Icons.playlist_add_check_rounded,
                                    color: const Color(0xFF5B5FEF),
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        word.german,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        word.translation,
                                        textDirection: TextDirection.rtl,
                                        style: const TextStyle(
                                          color: Color(0xFF5B5FEF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (word.difficulty != 'unspecified')
                                            _badge(
                                              word.difficulty == 'easy'
                                                  ? 'سهل'
                                                  : word.difficulty == 'medium'
                                                      ? 'متوسط'
                                                      : 'صعب',
                                            ),
                                          if (word.categoryName != null &&
                                              word.categoryName!.isNotEmpty)
                                            _badge(word.categoryName!),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        word.example,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          height: 1.35,
                                        ),
                                      ),
                                      if (word.exampleTranslation.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          word.exampleTranslation,
                                          textDirection: TextDirection.rtl,
                                          style: const TextStyle(
                                            color: Colors.black45,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
