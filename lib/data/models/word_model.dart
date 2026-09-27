class WordModel {
  const WordModel({
    required this.id,
    required this.german,
    required this.translation,
    required this.example,
    required this.builtin,
    required this.createdAt,
  });

  final int id;
  final String german;
  final String translation;
  final String example;
  final bool builtin;
  final DateTime createdAt;

  factory WordModel.fromMap(Map<String, Object?> map) {
    return WordModel(
      id: map['id'] as int,
      german: map['german'] as String,
      translation: map['translation'] as String,
      example: map['example'] as String,
      builtin: (map['builtin'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
