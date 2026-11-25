import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordcollector/library_theme.dart';
import 'package:wordcollector/main.dart';
import 'package:wordcollector/models/word_entry.dart';
import 'package:wordcollector/screens/collection_screen.dart';
import 'package:wordcollector/services/translation_service.dart';
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

  test(
    'returns common meanings first and keeps other dictionary senses',
    () async {
      final service = HybridTranslationService();
      Future<List<String>> lookup(String word, String source) async {
        final result = await service.translate(
          word,
          sourceLanguage: source,
          targetLanguage: source == 'hu' ? 'en' : 'hu',
        );
        expect(result.isOnline, isFalse, reason: word);
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
        ('en', 'abacus', 'számológép'),
        ('en', 'dictionary', 'szótár'),
      ]) {
        expect((await lookup(word, source)).first, expected, reason: word);
      }
      expect(
        await lookup('book', 'en'),
        containsAll(['könyv', 'jegyzetfüzet']),
      );
      expect(
        await lookup('spring', 'en'),
        containsAll(['tavasz', 'rugó', 'forrás']),
      );
      expect(await lookup('bank', 'en'), containsAll(['bank', 'part']));
      expect(await lookup('light', 'en'), contains('könnyű'));
      expect(await lookup('művész', 'hu'), contains('artist'));
    },
  );

  testWidgets('saves the chosen meaning and uses it in practice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'source_language_v1': 'en'});
    await tester.pumpWidget(_collectionWithTestTranslator(['tavasz', 'rugó']));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'spring');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Choose a translation for “spring”'), findsOneWidget);
    expect(await WordRepository().loadWords(), isEmpty);

    await tester.tap(find.text('rugó'));
    await tester.pumpAndSettle();
    expect((await WordRepository().loadWords()).single.translation, 'rugó');

    await _openPractice(tester);
    await _submit(tester, 'rugó');
    expect(find.text('Practice complete.'), findsOneWidget);
  });

  testWidgets('asks for confirmation before saving an online result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _collectionWithResult(
        const TranslationResult(['online result'], isOnline: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'some phrase');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.text('Check the online translation for “some phrase”'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await WordRepository().loadWords(), isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'some phrase',
    );
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
      tester.getCenter(find.text('word 0')),
    );
    await tester.pump(const Duration(seconds: 3));
    await hold.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look up translation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('new meaning'));
    await tester.pumpAndSettle();
    expect((await WordRepository().loadWords()).single.translation, 'answer 0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = (await WordRepository().loadWords()).single;
    expect(entry.id, '0');
    expect(entry.createdAt, DateTime(2020));
    expect(entry.translation, 'new meaning');
  });

  testWidgets(
    'only a three-second hold on a revealed word edits and saves it',
    (tester) async {
      _seedCollection(1);
      await tester.pumpWidget(_collectionWithTestTranslator());
      await tester.pumpAndSettle();

      final word = find.text('word 0');
      var hold = await tester.startGesture(tester.getCenter(word));
      await tester.pump(const Duration(seconds: 3));
      await hold.up();
      expect(find.text('Edit translation'), findsNothing);

      final translation = find.text('answer 0');
      await tester.drag(translation, const Offset(180, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      hold = await tester.startGesture(tester.getCenter(word));
      await tester.pump(const Duration(milliseconds: 2900));
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
