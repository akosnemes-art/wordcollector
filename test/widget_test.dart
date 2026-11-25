import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordcollector/app_info.dart';
import 'package:wordcollector/library_theme.dart';
import 'package:wordcollector/main.dart';
import 'package:wordcollector/models/word_entry.dart';
import 'package:wordcollector/screens/collection_screen.dart';
import 'package:wordcollector/services/translation_service.dart';
import 'package:wordcollector/services/wiktionary_client.dart';
import 'package:wordcollector/services/word_repository.dart';
import 'package:wordcollector/widgets/scratch_translation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the empty collection and opens the side menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WordCollectorApp());
    await tester.pumpAndSettle();

    expect(find.text('Collect your first word'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('Translation direction'), findsOneWidget);
    expect(find.text('Hungarian → English'), findsOneWidget);
  });

  testWidgets(
    'launch holds the credit, draws rules and then fades in the library',
    (tester) async {
      await tester.pumpWidget(const WordCollectorApp());
      final splash = find.byKey(const ValueKey('designer-splash'));
      expect(
        tester.getSize(splash),
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
      LibraryEntrance entrance() =>
          tester.widget<LibraryEntrance>(find.byType(LibraryEntrance));

      expect(
        find.descendant(of: splash, matching: find.text(designerName)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: splash, matching: find.text('Version $appVersion')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 2990));
      expect(splash, findsOneWidget);
      expect(entrance().rules.value, 0);
      expect(entrance().ink.value, 0);

      await tester.pump(const Duration(milliseconds: 670));
      expect(splash, findsNothing);
      expect(entrance().rules.value, inExclusiveRange(0, 1));
      expect(entrance().ink.value, 0);
      await tester.pump(const Duration(milliseconds: 540));
      expect(entrance().rules.value, 1);
      expect(entrance().ink.value, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      final version = find.text('Version $appVersion');
      expect(version, findsOneWidget);
      expect(
        tester.getTopLeft(version).dy,
        greaterThan(tester.getBottomLeft(find.byType(TextField)).dy),
      );
    },
  );

  testWidgets(
    'edits a word and translation and removes entries through the menu',
    (tester) async {
      _seedCollection(2);
      await tester.pumpWidget(_collectionWithTestTranslator());
      await tester.pumpAndSettle();
      final options = find.byTooltip('Options for word 0');
      expect(
        tester.getCenter(options).dx,
        lessThan(tester.getCenter(find.text('word 0')).dx),
      );
      await tester.tap(options);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit word'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'corrected word');
      await tester.enterText(fields.at(1), 'corrected translation');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final entries = await WordRepository().loadWords();
      expect(entries.first.id, '0');
      expect(entries.first.word, 'corrected word');
      expect(entries.first.translation, 'corrected translation');

      await tester.tap(find.byTooltip('Options for word 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('word 1'), findsNothing);
      expect((await WordRepository().loadWords()).map((entry) => entry.id), [
        '0',
      ]);
    },
  );

  testWidgets(
    'starts a saved reorder only after holding a word for 1.5 seconds',
    (tester) async {
      _seedCollection(3);
      await tester.pumpWidget(_collectionWithTestTranslator());
      await tester.pumpAndSettle();

      final first = find.text('word 0');
      final next = tester.getCenter(find.text('word 1'));
      final last = tester.getCenter(find.text('word 2'));
      var hold = await tester.startGesture(tester.getCenter(first));
      await tester.pump(const Duration(milliseconds: 1490));
      await hold.moveTo(next);
      await hold.up();
      await tester.pumpAndSettle();
      expect((await WordRepository().loadWords()).map((entry) => entry.id), [
        '0',
        '1',
        '2',
      ]);

      hold = await tester.startGesture(tester.getCenter(first));
      await tester.pump(const Duration(milliseconds: 1500));
      await hold.moveTo(next);
      await tester.pump(const Duration(milliseconds: 100));
      await hold.moveTo(last + const Offset(0, 25));
      await tester.pump(const Duration(milliseconds: 100));
      await hold.up();
      await tester.pumpAndSettle();
      expect(find.text('Edit translation'), findsNothing);
      expect((await WordRepository().loadWords()).map((entry) => entry.id), [
        '1',
        '0',
        '2',
      ]);
      expect(
        tester.getCenter(first).dy,
        greaterThan(tester.getCenter(find.text('word 1')).dy),
      );
    },
  );

  testWidgets('can drag a word over a page boundary', (tester) async {
    tester.view.physicalSize = const Size(410, 1130);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _seedCollection(10);
    await tester.pumpWidget(_collectionWithTestTranslator());
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    final from = tester.getCenter(find.text('word 7'));
    final after = tester.getCenter(find.text('word 8'));
    final drag = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 1500));
    await drag.moveTo(after - const Offset(0, 10));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    final order = (await WordRepository().loadWords())
        .map((entry) => entry.id)
        .toList();
    expect(order.sublist(6), ['6', '8', '7', '9']);
  });

  testWidgets('adds a known word and fades its translation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_collectionWithTestTranslator());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kutya');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('kutya'), findsOneWidget);
    expect(find.text('dog'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 700));
    final translation = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('dog'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(translation.opacity, 0);
  });

  testWidgets('rubbing reveals an old hidden translation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 70,
              child: ScratchTranslation(
                translation: 'dog',
                createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
              ),
            ),
          ),
        ),
      ),
    );

    AnimatedOpacity translationOpacity() => tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('dog'),
        matching: find.byType(AnimatedOpacity),
      ),
    );

    expect(translationOpacity().opacity, 0);
    await tester.drag(find.byType(ScratchTranslation), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(translationOpacity().opacity, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 700));
    expect(translationOpacity().opacity, 0);
  });

  test('translates modern vocabulary and inflected nouns offline in both directions', () async {
    final service = HybridTranslationService(lookupOnline: (_, _) async => []);
    Future<List<String>> lookup(String word, String source) async {
      final result = await service.translate(
        word,
        sourceLanguage: source,
        targetLanguage: source == 'hu' ? 'en' : 'hu',
      );
      return result.options;
    }

    for (final (source, word, expected) in [
      ('hu', '  Alma ', 'apple'),
      ('hu', 'könyv', 'book'),
      ('hu', 'ház', 'house'),
      ('hu', 'macska', 'cat'),
      ('hu', 'kenyér', 'bread'),
      ('en', 'CAT', 'macska'),
      ('en', 'book', 'könyv'),
      ('en', 'table', 'asztal'),
      ('en', 'water', 'víz'),
      ('en', 'go', 'megy'),
      ('en', 'to go', 'megy'),
      ('en', 'goodbye', 'viszlát'),
      ('en', 'Good morning!', 'jó reggelt'),
      ('en', 'abacus', 'abakusz'),
      ('en', 'dictionary', 'szótár'),
      ('en', 'translation', 'fordítás'),
      ('en', 'train', 'vonat'),
      ('en', 'pineapple', 'ananász'),
      ('hu', 'eszik', 'eat'),
      ('hu', 'könyvet', 'book'),
      ('hu', 'kutyák', 'dogs'),
      ('hu', 'repülőgép', 'airplane'),
    ]) {
      expect((await lookup(word, source)).first, expected, reason: word);
    }
    expect(
      await lookup('spring', 'en'),
      containsAll(['tavasz', 'rugó', 'forrás']),
    );
    expect(await lookup('művész', 'hu'), contains('artist'));
  });

  test('looks up online even when an offline entry exists', () async {
    final requests = <(String, String)>[];
    final service = HybridTranslationService(
      lookupOnline: (word, source) async {
        requests.add((word, source));
        return word == 'bögre' ? ['mug', 'cup'] : [];
      },
    );
    final result = await service.translate(
      'Bögre!',
      sourceLanguage: 'hu',
      targetLanguage: 'en',
    );
    expect(result.primary, 'mug');
    expect(result.options, contains('cup'));
    final fallback = await service.translate(
      'kutyák',
      sourceLanguage: 'hu',
      targetLanguage: 'en',
    );
    expect(fallback.primary, 'dogs');
    expect(requests, [('bögre', 'hu'), ('kutyák', 'hu')]);
  });

  test(
    'parses only the requested languages and prioritizes current senses',
    () {
      expect(
        WiktionaryClient.parseResponse('''{
      "definitions": [
        {"lang_code":"en","senses":[{"glosses":["unrelated"]}]},
        {"lang_code":"hu","senses":[
          {"glosses":["canoodle"],"tags":["archaic"]},
          {"glosses":["chow down"],"tags":["slang"]},
          {"glosses":["to eat (to consume food)", "to eat, consume"]},
          {"glosses":["third-person plural of eszik"],"tags":["form-of"]}
        ]}
      ]
    }''', 'hu'),
        ['eat', 'consume', 'chow down'],
      );
      expect(
        WiktionaryClient.parseResponse('''{
      "translations": [{"lang_code":"en","translations":[
        {"lang_code":"de","word":"Katze"},
        {"lang_code":"hu","word":"cica","tags":["childish"]},
        {"lang_code":"hu","word":"macska"}
      ]}]
    }''', 'en'),
        ['macska', 'cica'],
      );
    },
  );

  testWidgets('saves the best meaning without opening a chooser', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'source_language_v1': 'en'});
    await tester.pumpWidget(_collectionWithTestTranslator(['tavasz', 'rugó']));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spring');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect((await WordRepository().loadWords()).single.translation, 'tavasz');
    await _openPractice(tester);
    await _submit(tester, 'tavasz');
    expect(find.text('Practice complete.'), findsOneWidget);
  });

  testWidgets('can look up and replace a previously saved translation', (
    tester,
  ) async {
    _seedCollection(1);
    await tester.pumpWidget(
      _collectionWithTestTranslator(['new meaning', 'another meaning']),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('answer 0'), const Offset(180, 0));
    await tester.pumpAndSettle();
    final hold = await tester.startGesture(
      tester.getCenter(find.text('answer 0')),
    );
    await tester.pump(const Duration(seconds: 2));
    await hold.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look up translation'));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
    await tester.tap(find.text('another meaning'));
    await tester.pumpAndSettle();
    expect((await WordRepository().loadWords()).single.translation, 'answer 0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = (await WordRepository().loadWords()).single;
    expect(entry.id, '0');
    expect(entry.createdAt, DateTime(2020));
    expect(entry.translation, 'another meaning');
  });

  testWidgets(
    'only a two-second hold on a visible translation edits and saves it',
    (tester) async {
      _seedCollection(1);
      await tester.pumpWidget(_collectionWithTestTranslator());
      await tester.pumpAndSettle();

      final translation = find.text('answer 0');
      var hold = await tester.startGesture(tester.getCenter(translation));
      await tester.pump(const Duration(seconds: 2));
      await hold.up();
      expect(find.text('Edit translation'), findsNothing);

      await tester.drag(translation, const Offset(180, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      hold = await tester.startGesture(tester.getCenter(translation));
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.text('Edit translation'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await hold.up();
      await tester.pumpAndSettle();

      expect(find.text('Edit translation'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'new answer');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await WordRepository().loadWords()).single;
      expect(saved.word, 'word 0');
      expect(saved.translation, 'new answer');
      expect(saved.sourceLanguage, isNull);
    },
  );

  testWidgets(
    'practice reshuffles after three mistakes and restores saved order',
    (tester) async {
      _seedCollection(3);
      await tester.pumpWidget(_collectionWithTestTranslator());
      await tester.pumpAndSettle();
      await _openPractice(tester);
      final first = _practiceWord(tester);
      expect(first, isNot('word 0'));
      for (var attempt = 0; attempt < 3; attempt++) {
        await _submit(tester, 'wrong');
      }
      expect(
        find.text('Three incorrect attempts. The deck has been shuffled.'),
        findsOneWidget,
      );
      expect(_practiceWord(tester), isNot(first));

      for (var index = 0; index < 3; index++) {
        await _submit(
          tester,
          _practiceWord(tester).replaceFirst('word', '  ANSWER  '),
        );
      }
      expect(find.text('Practice complete.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('word 0')).dy,
        lessThan(tester.getTopLeft(find.text('word 1')).dy),
      );
      expect(
        tester.getTopLeft(find.text('word 1')).dy,
        lessThan(tester.getTopLeft(find.text('word 2')).dy),
      );
      expect((await WordRepository().loadWords()).map((entry) => entry.id), [
        '0',
        '1',
        '2',
      ]);
    },
  );

  for (final (wordCount, limit) in [(8, 1), (9, 2), (16, 2), (17, 3)]) {
    testWidgets('$wordCount collected words allow $limit practice reveals', (
      tester,
    ) async {
      _seedCollection(wordCount);
      await tester.pumpWidget(_collectionWithTestTranslator());
      await tester.pumpAndSettle();
      await _openPractice(tester);

      final reveal = find.text('Reveal translation');
      for (var used = 1; used <= limit; used++) {
        await tester.tap(reveal);
        await tester.pumpAndSettle();
        expect(find.text('$used / $limit reveals used'), findsOneWidget);
        final answer = _practiceWord(tester).replaceFirst('word', 'answer');
        expect(find.text(answer), findsOneWidget);
        await _submit(tester, answer);
      }
      await tester.tap(reveal);
      await tester.pumpAndSettle();
      expect(
        find.text('Reveal limit reached. The deck has been shuffled.'),
        findsOneWidget,
      );
      expect(find.text('WORD 1 OF $wordCount'), findsOneWidget);
      expect(find.text('0 / $limit reveals used'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to collection'));
      await tester.pumpAndSettle();
      expect(find.text('Word Collector'), findsOneWidget);
    });
  }
}

Widget _collectionWithTestTranslator([List<String> options = const ['dog']]) =>
    _collectionWithResult(TranslationResult(options));

Widget _collectionWithResult(TranslationResult result) => MaterialApp(
  theme: libraryTheme(),
  home: CollectionScreen(translationService: _TestTranslator(result)),
);

void _seedCollection(int count) {
  SharedPreferences.setMockInitialValues({
    'word_entries_v1': jsonEncode([
      for (var index = 0; index < count; index++)
        WordEntry(
          id: '$index',
          word: 'word $index',
          translation: 'answer $index',
          createdAt: DateTime(2020),
        ).toJson(),
    ]),
  });
}

Future<void> _openPractice(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Practice mode'));
  await tester.pumpAndSettle();
}

String _practiceWord(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('practice-word'))).data!;

Future<void> _submit(WidgetTester tester, String answer) async {
  await tester.enterText(find.byType(TextField), answer);
  await tester.tap(find.text('Check answer'));
  await tester.pumpAndSettle();
}

class _TestTranslator implements TranslationService {
  const _TestTranslator(this.result);

  final TranslationResult result;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async => result;
}
