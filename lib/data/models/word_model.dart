class WordModel {
  const WordModel({
    required this.id,
    required this.german,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    required this.difficulty,
    required this.categoryId,
    required this.categoryName,
    required this.builtin,
    required this.createdAt,
  });

  final int id;
  final String german;
  final String translation;
  final String example;
  final String exampleTranslation;
  final String difficulty;
  final int? categoryId;
  final String? categoryName;
  final bool builtin;
  final DateTime createdAt;

  factory WordModel.fromMap(Map<String, Object?> map) {
    return WordModel(
      id: map['id'] as int,
      german: map['german'] as String,
      translation: map['translation'] as String,
      example: map['example'] as String,
      exampleTranslation:
          (map['example_translation'] as String?)?.trim() ?? '',
      difficulty: (map['difficulty'] as String?)?.trim().isNotEmpty == true
          ? (map['difficulty'] as String).trim()
          : 'unspecified',
      categoryId: map['category_id'] as int?,
      categoryName: (map['category_name'] as String?)?.trim(),
      builtin: (map['builtin'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
