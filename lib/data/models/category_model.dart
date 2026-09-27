class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.wordCount,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int wordCount;
  final DateTime createdAt;

  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      wordCount: (map['word_count'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
