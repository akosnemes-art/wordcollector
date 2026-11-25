import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';

class WordRepository {
  static const _wordsKey = 'word_entries_v1';
  static const _sourceLanguageKey = 'source_language_v1';

  Future<List<WordEntry>> loadWords() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_wordsKey);
    if (stored == null || stored.isEmpty) return [];

    try {
      final decoded = jsonDecode(stored) as List<dynamic>;
      return decoded
          .map((item) => WordEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> saveWords(List<WordEntry> words) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _wordsKey,
      jsonEncode(words.map((word) => word.toJson()).toList()),
    );
    if (!saved) throw const FormatException('Could not save the collection');
  }

  Future<String> loadSourceLanguage() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_sourceLanguageKey) ?? 'hu';
  }

  Future<void> saveSourceLanguage(String language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sourceLanguageKey, language);
  }
}
