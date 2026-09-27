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
    if (mounted) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('قاموس الكلمات'), actions: [
      IconButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWordScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
      ),
    ]),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث بالألمانية أو العربية',
          ),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: _data.length,
          itemBuilder: (context, index) {
            final word = _data[index];
            return Dismissible(
              key: ValueKey(word.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _repository.remove(word.id),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: ListTile(
                title: Text(word.german, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(word.translation + '\n' + word.example, textDirection: TextDirection.ltr),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
    ]),
  );
}
