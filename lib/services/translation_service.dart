import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'slob_dictionary.dart';

abstract interface class TranslationService {
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  });
}

class HybridTranslationService implements TranslationService {
  static const _assets = {
    'hu-en': 'dictionaries/freedict-hun-eng-0.4.1.slob',
    'en-hu': 'dictionaries/freedict-eng-hun-0.2.1.slob',
  };

  final _dictionaries = <String, Future<SlobDictionary>>{};

  Future<SlobDictionary> _loadDictionary(String asset) async {
    final bytes = await rootBundle.load(asset);
    return compute(SlobDictionary.new, bytes);
  }

  @override
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final cleanText = text.trim();
    final pair = '$sourceLanguage-$targetLanguage';
    final asset = _assets[pair];
    if (asset != null) {
      final dictionary = await _dictionaries.putIfAbsent(
        pair,
        () => _loadDictionary(asset),
      );
      final result = dictionary.lookup(cleanText);
      if (result != null) return result;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': cleanText,
        'langpair': '$sourceLanguage|$targetLanguage',
      });
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw const TranslationException(
          'The translation service is unavailable.',
        );
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5));
      final json = jsonDecode(body) as Map<String, dynamic>;
      final responseData = json['responseData'] as Map<String, dynamic>?;
      final translated = responseData?['translatedText'] as String?;
      if (translated == null || translated.trim().isEmpty) {
        throw const TranslationException('No translation was returned.');
      }
      return _decodeBasicEntities(translated.trim());
    } on TranslationException {
      rethrow;
    } on Object {
      throw const TranslationException(
        'Could not translate. Check your internet connection and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String _decodeBasicEntities(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}

class TranslationException implements Exception {
  const TranslationException(this.message);

  final String message;
}
