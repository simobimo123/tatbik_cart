import 'package:flutter/material.dart';
import '../../../data/models/word_model.dart';
import '../../../data/repositories/discovery_repository.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _repository = DiscoveryRepository();

  WordModel? _word;
  int _remaining = 0;
  bool _loading = true;
  bool _busy = false;
  String? _feedback;
  bool _feedbackPositive = false;

  static const _primary = Color(0xFF5B5FEF);
  static const _green = Color(0xFF16A88F);
  static const _red = Color(0xFFE45757);

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _feedback = null;
    });

    final words = await _repository.getPendingWords();
    final count = await _repository.pendingCount();

    if (!mounted) return;

    setState(() {
      _word = words.isEmpty ? null : words.first;
      _remaining = count;
      _loading = false;
      _busy = false;
    });
  }

  Future<void> _answer(bool known) async {
    final word = _word;
    if (word == null || _busy) return;

    setState(() => _busy = true);

    await _repository.answer(word, known: known);

    if (!mounted) return;

    setState(() {
      _feedbackPositive = known;
      _feedback = known
          ? 'ممتاز، لن تدخل هذه الكلمة في المراجعة.'
          : 'ستدخل هذه الكلمة الآن في بطاقات المراجعة.';
    });

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    await _loadNext();
  }

  Widget _buildCompleted() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اكتشاف الكلمات',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F9F5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 46,
                  color: _green,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'انتهت الكلمات المتاحة حاليًا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'أضف كلمات جديدة إلى قاعدة الكلمات، وستظهر هنا تلقائيًا لاكتشافها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('اكتشاف الكلمات')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final word = _word;
    if (word == null) {
      return _buildCompleted();
    }

    final progress =
        _remaining == 0 ? 0.0 : ((_remaining - 1) / _remaining).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اكتشاف الكلمات',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'هل تعرف هذه الكلمة؟',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$_remaining متبقية',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress,
                backgroundColor: const Color(0xFFE5E7EF),
                valueColor: const AlwaysStoppedAnimation(_primary),
              ),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(word.id),
                constraints: const BoxConstraints(minHeight: 390),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE9EAF2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 22,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF0FF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: _primary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Deutsch',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      word.german,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اختر إجابتك بالأسفل',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_feedback != null)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: 1,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _feedbackPositive
                                ? const Color(0xFFE9F9F5)
                                : const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _feedbackPositive
                                    ? Icons.check_circle_rounded
                                    : Icons.school_rounded,
                                color: _feedbackPositive ? _green : _red,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _feedback!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              if (!_feedbackPositive) ...[
                                const SizedBox(height: 6),
                                Text(
                                  word.translation,
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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
                      side: const BorderSide(color: _red, width: 1.5),
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
            const SizedBox(height: 12),
            const Text(
              'الكلمة التي تقول عنها «لا أعرفها» تدخل مباشرة في المراجعة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
