class WordModel {
  const WordModel({
    required this.id,
    required this.german,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    required this.builtin,
    required this.createdAt,
  });

  final int id;
  final String german;
  final String translation;
  final String example;
  final String exampleTranslation;
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
      builtin: (map['builtin'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
