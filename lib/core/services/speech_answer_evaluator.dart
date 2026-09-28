class SpeechAnswerEvaluator {
  const SpeechAnswerEvaluator._();

  static bool matches(
    String spoken,
    String expected, {
    bool sentence = false,
  }) {
    final actual = normalize(spoken);
    final target = normalize(expected);

    if (actual.isEmpty || target.isEmpty) return false;
    if (RegExp(r'[\\u0600-\\u06FF]').hasMatch(actual)) return false;
    if (actual == target) return true;

    if (!sentence) return false;

    final distance = _levenshtein(actual, target);
    final maxLength = actual.length > target.length ? actual.length : target.length;
    final similarity =
        maxLength == 0 ? 1.0 : 1 - (distance / maxLength);

    final actualWords = actual.split(' ');
    final targetWords = target.split(' ');
    final overlap = _wordOverlap(actualWords, targetWords);

    return similarity >= 0.86 || overlap >= 0.82;
  }

  static String normalize(String value) {
    var text = value.toLowerCase().trim();

    const replacements = {
      'ä': 'ae',
      'ö': 'oe',
      'ü': 'ue',
      'ß': 'ss',
    };

    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    text = text
        .replaceAll(RegExp(r'[.,!?;:()\[\]{}"„“”‚‘’—–-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const fillers = {
      'äh',
      'ähm',
      'eh',
      'ehm',
      'hm',
      'hmm',
      'aeh',
      'aehm',
    };
    final words = text
        .split(' ')
        .where((word) => word.isNotEmpty && !fillers.contains(word))
        .toList();

    return words.join(' ');
  }

  static double _wordOverlap(
    List<String> actual,
    List<String> target,
  ) {
    if (actual.isEmpty || target.isEmpty) return 0;

    final actualSet = actual.toSet();
    var hits = 0;

    for (final word in target) {
      if (actualSet.contains(word)) hits++;
    }

    return hits / target.length;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(
      b.length + 1,
      (index) => index,
    );

    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;

      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;

        final insert = current[j] + 1;
        final remove = previous[j + 1] + 1;
        final replace = previous[j] + cost;

        current[j + 1] = insert < remove
            ? (insert < replace ? insert : replace)
            : (remove < replace ? remove : replace);
      }

      previous = current;
    }

    return previous[b.length];
  }
}
