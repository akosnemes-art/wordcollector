class WordEntry {
  const WordEntry({
    required this.id,
    required this.word,
    required this.translation,
    required this.createdAt,
    this.sourceLanguage,
  });

  final String id;
  final String word;
  final String translation;
  final DateTime createdAt;
  final String? sourceLanguage;

  String? get targetLanguage => switch (sourceLanguage) {
    'hu' => 'en',
    'en' => 'hu',
    _ => null,
  };

  WordEntry withTranslation(String value) => WordEntry(
    id: id,
    word: word,
    translation: value,
    createdAt: createdAt,
    sourceLanguage: sourceLanguage,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'word': word,
    'translation': translation,
    'createdAt': createdAt.toIso8601String(),
    'sourceLanguage': ?sourceLanguage,
  };

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    return WordEntry(
      id: json['id'] as String,
      word: json['word'] as String,
      translation: json['translation'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sourceLanguage: json['sourceLanguage'] as String?,
    );
  }
}
