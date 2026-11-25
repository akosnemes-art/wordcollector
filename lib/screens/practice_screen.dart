import 'package:flutter/material.dart';

import '../library_theme.dart';
import '../models/word_entry.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.words});

  final List<WordEntry> words;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _answer = TextEditingController();
  final _answerFocus = FocusNode();
  late final List<WordEntry> _deck;
  int _position = 0;
  int _mistakes = 0;
  int _revealsUsed = 0;
  bool _revealed = false;
  String? _feedback;

  WordEntry get _word => _deck[_position];
  int get _revealLimit => (_deck.length + 7) ~/ 8;

  @override
  void initState() {
    super.initState();
    _deck = List.of(widget.words);
    _shuffle();
  }

  @override
  void dispose() {
    _answer.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  void _shuffle() {
    final firstWord = _deck.first;
    _deck.shuffle();
    if (_deck.length > 1 && identical(_deck.first, firstWord)) {
      _deck.add(_deck.removeAt(0));
    }
  }

  void _restart(String reason) {
    _answer.clear();
    setState(() {
      _shuffle();
      _position = 0;
      _mistakes = 0;
      _revealsUsed = 0;
      _revealed = false;
      _feedback = reason;
    });
  }

  String _normalize(String answer) =>
      answer.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void _checkAnswer() {
    final answer = _normalize(_answer.text);
    if (answer.isEmpty) return;
    if (answer == _normalize(_word.translation)) {
      if (_position == _deck.length - 1) {
        Navigator.pop(context, true);
        return;
      }
      _answer.clear();
      setState(() {
        _position++;
        _mistakes = 0;
        _revealed = false;
        _feedback = 'Correct.';
      });
    } else if (_mistakes == 2) {
      _restart('Three incorrect attempts. The deck has been shuffled.');
    } else {
      _answer.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _answer.text.length,
      );
      setState(() {
        _mistakes++;
        _feedback = _mistakes == 1
            ? 'Try again. Two attempts left.'
            : 'Try again. One attempt left.';
      });
    }
    _answerFocus.requestFocus();
  }

  void _reveal() {
    if (_revealed) return;
    if (_revealsUsed >= _revealLimit) {
      _restart('Reveal limit reached. The deck has been shuffled.');
      return;
    }
    setState(() {
      _revealsUsed++;
      _revealed = true;
      _feedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = switch (_word.targetLanguage) {
      'hu' => 'Hungarian',
      'en' => 'English',
      _ => null,
    };
    return Scaffold(
      body: LibraryPage(
        child: Column(
          children: [
            LibraryHeading(
              title: 'Practice mode',
              leading: IconButton(
                tooltip: 'Back to collection',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              detail: 'WORD ${_position + 1} OF ${_deck.length}',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      border: Border.all(color: libraryRule),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target == null
                              ? 'TRANSLATE THIS WORD'
                              : 'TRANSLATE INTO ${target.toUpperCase()}',
                          style: libraryLabel,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _word.word,
                          key: const ValueKey('practice-word'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (_revealed) ...[
                          const SizedBox(height: 10),
                          Text(
                            _word.translation,
                            style: const TextStyle(
                              fontFamily: librarySerif,
                              fontSize: 22,
                              color: libraryAccent,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _answer,
                    focusNode: _answerFocus,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _checkAnswer(),
                    decoration: const InputDecoration(
                      labelText: 'Your translation',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _checkAnswer,
                        child: const Text('Check answer'),
                      ),
                      OutlinedButton(
                        onPressed: _revealed ? null : _reveal,
                        child: const Text('Reveal translation'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$_revealsUsed / $_revealLimit reveals used',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_feedback case final feedback?) ...[
                    const SizedBox(height: 8),
                    Semantics(liveRegion: true, child: Text(feedback)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
