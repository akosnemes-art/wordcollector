import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WiktionaryClient {
  const WiktionaryClient();

  static const _timeout = Duration(milliseconds: 2500);
  static const _userAgent =
      'WordCollector/0.1.2 (https://github.com/akosnemes-art/wordcollector)';
  static const _datedTags = {
    'abbreviation',
    'alt-of',
    'archaic',
    'dated',
    'dialectal',
    'form-of',
    'historical',
    'nonstandard',
    'obsolete',
    'rare',
    'regional',
  };
  static const _specializedTags = {
    'childish',
    'derogatory',
    'figuratively',
    'slang',
    'vulgar',
  };
  static final _parentheses = RegExp(r'\([^()]*\)');
  static final _synonym = RegExp(
    r'^synonym of .+?\(“([^”]+)”\)',
    caseSensitive: false,
  );
  static final _term = RegExp(
    r"^[\p{L}\p{N}]+(?:[-'’ ][\p{L}\p{N}]+){0,5}$",
    unicode: true,
  );
  static final _definition = RegExp(
    r'^(?:an?|the) |\b(?:alternative form|form of|synonym of|plural of|type of|kind of|someone|something|that|which)\b',
    caseSensitive: false,
  );
  static final _wikiMarkup = RegExp(r'[\[\]{}<>]');
  static final _edgePunctuation = RegExp(r'[.!?:]+$');
  static final _multipleSpaces = RegExp(r'\s+');
  static final _senseSeparator = RegExp(r'[,;]');

  Future<List<String>> lookup(String word, String sourceLanguage) async {
    final resource = sourceLanguage == 'hu' ? 'definitions' : 'translations';
    final uri = Uri(
      scheme: 'https',
      host: 'api.wiktapi.dev',
      pathSegments: ['v1', 'en', 'word', word, resource],
      queryParameters: {'lang': sourceLanguage},
    );
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final response = await _fetch(client, uri).timeout(_timeout);
      return parseResponse(response, sourceLanguage);
    } on IOException {
      return const [];
    } on TimeoutException {
      return const [];
    } on FormatException {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _fetch(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return '{}';
    return response.transform(utf8.decoder).join();
  }

  static List<String> parseResponse(String body, String sourceLanguage) {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) return const [];
    final hungarian = sourceLanguage == 'hu';
    final entries = _objects(data[hungarian ? 'definitions' : 'translations']);
    final plain = <String>{};
    final specialized = <String>{};
    for (final entry in entries) {
      if (entry['lang_code'] != sourceLanguage) continue;
      for (final item in _objects(
        entry[hungarian ? 'senses' : 'translations'],
      )) {
        final tags = item['tags'];
        final tagSet = tags is List
            ? tags.whereType<String>().toSet()
            : <String>{};
        if (tagSet.intersection(_datedTags).isNotEmpty) continue;
        final results = tagSet.intersection(_specializedTags).isEmpty
            ? plain
            : specialized;
        if (hungarian) {
          final glosses = item['glosses'];
          if (glosses is List && glosses.isNotEmpty && glosses.last is String) {
            results.addAll(_glossTranslations(glosses.last as String));
          }
        } else if (item['lang_code'] == 'hu') {
          final word = item['word'];
          if (word is String &&
              word.trim().isNotEmpty &&
              !_wikiMarkup.hasMatch(word)) {
            results.add(word.trim());
          }
        }
      }
    }
    return {...plain, ...specialized}.toList(growable: false);
  }

  static Iterable<Map<String, dynamic>> _objects(Object? value) =>
      value is List ? value.whereType<Map<String, dynamic>>() : const [];

  static Iterable<String> _glossTranslations(String gloss) sync* {
    final synonym = _synonym.firstMatch(gloss);
    if (synonym != null) {
      gloss = synonym.group(1)!;
    } else {
      while (gloss.contains(_parentheses)) {
        gloss = gloss.replaceAll(_parentheses, ' ');
      }
    }
    gloss = gloss.trim();
    if (gloss.startsWith('to ')) gloss = gloss.substring(3);
    for (final part in gloss.split(_senseSeparator)) {
      final term = part
          .trim()
          .replaceAll(_multipleSpaces, ' ')
          .replaceFirst(_edgePunctuation, '');
      if (_term.hasMatch(term) && !_definition.hasMatch(term)) yield term;
    }
  }
}
