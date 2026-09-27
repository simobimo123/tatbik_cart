import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/word_repository.dart';
import 'add_word_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  final _repository = WordRepository();
  List<WordModel> _data = [];

  @override
  void initState() { super.initState(); _load(); _search.addListener(_load); }
  @override
  void dispose() { _search.removeListener(_load); _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    final data = await _repository.getWords(_search.text);
    if (mounted) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('قاموس الكلمات'),
      actions: [
        IconButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWordScreen()));
            _load();
          },
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          icon: const Icon(Icons.add_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: TextField(
          controller: _search,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث بالألمانية أو العربية'),
        ),
      ),
      Expanded(
        child: _data.isEmpty
            ? const Center(child: Text('لا توجد كلمات مطابقة'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _data.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final word = _data[index];
                  return Dismissible(
                    key: ValueKey(word.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _repository.remove(word.id),
                    background: Container(
                      decoration: BoxDecoration(color: const Color(0xFFE95D6A), borderRadius: BorderRadius.circular(20)),
                      alignment: Alignment.centerRight, padding: const EdgeInsets.all(20),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                    ),
                    child: Material(
                      color: Colors.white, borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 44, height: 44,
                            decoration: BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.translate_rounded, color: Color(0xFF5B5FEF))),
                          const SizedBox(width: 13),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(word.german, textDirection: TextDirection.ltr,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(word.translation, textDirection: TextDirection.rtl,
                                style: const TextStyle(color: Color(0xFF5B5FEF), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 7),
                            Text(word.example, textDirection: TextDirection.ltr,
                                style: const TextStyle(color: Colors.black54, height: 1.35)),
                          ])),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]),
  );
}
