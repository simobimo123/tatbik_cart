import 'package:flutter_test/flutter_test.dart';

import '../lib/core/services/speech_answer_evaluator.dart';

void main() {
  group('SpeechAnswerEvaluator', () {
    test('matches exact German word', () {
      expect(
        SpeechAnswerEvaluator.matches('Haus', 'Haus'),
        isTrue,
      );
    });

    test('accepts German umlaut normalization', () {
      expect(
        SpeechAnswerEvaluator.matches('schon', 'schön'),
        isTrue,
      );
      expect(
        SpeechAnswerEvaluator.matches('gross', 'groß'),
        isTrue,
      );
    });

    test('ignores punctuation and fillers', () {
      expect(
        SpeechAnswerEvaluator.matches(
          'äh, ich wohne in Berlin.',
          'Ich wohne in Berlin.',
          sentence: true,
        ),
        isTrue,
      );
    });

    test('rejects a clearly wrong word', () {
      expect(
        SpeechAnswerEvaluator.matches('Bonn', 'Berlin'),
        isFalse,
      );
    });

    test('matches a slightly noisy sentence', () {
      expect(
        SpeechAnswerEvaluator.matches(
          'Ich wohne in Berlin',
          'Ich wohne in Berlin.',
          sentence: true,
        ),
        isTrue,
      );
    });
  });
}
