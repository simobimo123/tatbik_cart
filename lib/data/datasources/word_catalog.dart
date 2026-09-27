import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class WordCatalogItem {
  const WordCatalogItem({
    required this.german,
    required this.translation,
    required this.example,
  });

  final String german;
  final String translation;
  final String example;
}

class WordCatalog {
  const WordCatalog._();

  static const assetPath = 'assets/data/german_words.json';

  static Future<List<WordCatalogItem>> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid German word catalog format.');
    }

    final words = decoded['words'];
    if (words is! List) {
      throw const FormatException('The "words" field must be a list.');
    }

    final result = <WordCatalogItem>[];

    for (final item in words) {
      if (item is! Map) continue;

      final german = item['german']?.toString().trim() ?? '';
      final translation = item['translation']?.toString().trim() ?? '';
      final example = item['example']?.toString().trim() ?? '';

      if (german.isEmpty || translation.isEmpty || example.isEmpty) {
        continue;
      }

      result.add(
        WordCatalogItem(
          german: german,
          translation: translation,
          example: example,
        ),
      );
    }

    return result;
  }
}
