import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'common_translations.dart';
import 'slob_dictionary.dart';
import 'wiktionary_client.dart';

abstract interface class TranslationService {
  Future<TranslationResult> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  });
}

class TranslationResult {
  const TranslationResult(this.options);

  final List<String> options;

  String get primary => options.first;
}

class HybridTranslationService implements TranslationService {
  HybridTranslationService({
    Future<List<String>> Function(String word, String sourceLanguage)?
    lookupOnline,
  }) : _lookupOnline = lookupOnline ?? const WiktionaryClient().lookup;

  static const _assets = {
    'hu-en': 'dictionaries/freedict-hun-eng-0.4.1.slob',
    'en-hu': 'dictionaries/freedict-eng-hun-0.2.1.slob',
  };
  static final _closingPunctuation = RegExp(r'[!?]+$');

  final Future<List<String>> Function(String, String) _lookupOnline;
  final _dictionaries = <String, Future<SlobDictionary>>{};
  late final _lexicon = _loadLexicon();

  Future<SlobDictionary> _loadDictionary(
    String asset, {
    required bool hungarianSource,
  }) async {
    final bytes = await rootBundle.load(asset);
    return compute((data) => SlobDictionary(data, hungarianSource), bytes);
  }

  Future<Map<String, Map<String, List<String>>>> _loadLexicon() async {
    final bytes = await rootBundle.load(
      'dictionaries/wiktionary-hu-en.json.gz',
    );
    return compute(_decodeLexicon, Uint8List.sublistView(bytes));
  }

  static Map<String, Map<String, List<String>>> _decodeLexicon(
    Uint8List bytes,
  ) {
    final data =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    return data.map(
      (language, words) => MapEntry(
        language,
        (words as Map<String, dynamic>).map(
          (word, options) =>
              MapEntry(word, (options as List<dynamic>).cast<String>()),
        ),
      ),
    );
  }

  @override
  Future<TranslationResult> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final asset = _assets['$sourceLanguage-$targetLanguage'];
    if (asset == null) {
      throw const TranslationException(
        'Choose Hungarian or English for lookup.',
      );
    }
    final hungarian = sourceLanguage == 'hu';
    final spelling = text
        .trim()
        .replaceFirst(_closingPunctuation, '')
        .trimRight();
    final normalized = normalizeDictionaryKey(
      hungarian ? fixHungarianAccents(spelling) : spelling,
    );
    final key = !hungarian && normalized.startsWith('to ')
        ? normalized.substring(3)
        : normalized;
    if (key.isEmpty) {
      throw const TranslationException('Enter a word to translate.');
    }

    final lookup = _lookupOnline(key, sourceLanguage);
    final entries = (await _lexicon)[sourceLanguage];
    final local = entries?[normalized] ?? entries?[key] ?? const <String>[];
    final online = await lookup;
    final preferred = commonTranslations[sourceLanguage]?[key];
    final options = <String, String>{};
    void add(String word) {
      final cleaned = hungarian
          ? word.trim()
          : fixHungarianAccents(word.trim());
      if (cleaned.isNotEmpty) {
        options.putIfAbsent(normalizeDictionaryKey(cleaned), () => cleaned);
      }
    }

    if (preferred != null) add(preferred);
    // Keep a locally ranked equivalent when the live dictionary confirms it.
    if (local.isNotEmpty &&
        online.any(
          (term) =>
              normalizeDictionaryKey(term) ==
              normalizeDictionaryKey(local.first),
        )) {
      add(local.first);
    }
    online.forEach(add);
    local.forEach(add);
    if (options.isEmpty) {
      final dictionary = await _dictionaries.putIfAbsent(
        asset,
        () => _loadDictionary(asset, hungarianSource: hungarian),
      );
      dictionary.lookup(spelling).forEach(add);
      if (!hungarian && !normalized.startsWith('to ')) {
        dictionary.lookup('to $key').forEach(add);
      }
    }
    if (options.isEmpty) {
      throw const TranslationException(
        'No dictionary entry found. Check the spelling or try the base word.',
      );
    }
    return TranslationResult(options.values.take(8).toList(growable: false));
  }
}

class TranslationException implements Exception {
  const TranslationException(this.message);

  final String message;
}
