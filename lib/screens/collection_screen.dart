import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../library_theme.dart';
import '../models/word_entry.dart';
import '../services/translation_service.dart';
import '../services/word_repository.dart';
import '../widgets/translation_editor.dart';
import '../widgets/word_row.dart';
import 'practice_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, this.repository, this.translationService});

  final WordRepository? repository;
  final TranslationService? translationService;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  static const _wordsPerPage = 8;

  late final WordRepository _repository;
  late final TranslationService _translationService;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  List<WordEntry> _words = [];
  int _page = 0;
  String _sourceLanguage = 'hu';
  bool _loading = true;
  bool _translating = false;
  bool _saving = false;

  String get _targetLanguage => _sourceLanguage == 'hu' ? 'en' : 'hu';
  String get _direction =>
      _sourceLanguage == 'hu' ? 'Hungarian → English' : 'English → Hungarian';
  int get _pageCount =>
      math.max(1, (_words.length + _wordsPerPage - 1) ~/ _wordsPerPage);
  bool get _busy => _loading || _translating || _saving;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WordRepository();
    _translationService =
        widget.translationService ?? HybridTranslationService();
    _load();
  }

  Future<void> _load() async {
    final words = await _repository.loadWords();
    final source = await _repository.loadSourceLanguage();
    if (!mounted) return;
    setState(() {
      _words = words;
      _sourceLanguage = source;
      _page = _pageCount - 1;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _saveCollection(List<WordEntry> words, {int? page}) async {
    setState(() => _saving = true);
    try {
      await _repository.saveWords(words);
      if (!mounted) return false;
      setState(() {
        _words = words;
        _page = page ?? _page;
      });
      return true;
    } on Exception {
      if (mounted) _showMessage('Could not save your collection. Try again.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addWord() async {
    final word = _input.text.trim();
    if (word.isEmpty || _busy) return;
    setState(() => _translating = true);
    try {
      final source = _sourceLanguage;
      final result = await _translationService.translate(
        word,
        sourceLanguage: source,
        targetLanguage: _targetLanguage,
      );
      if (!mounted) return;
      final now = DateTime.now();
      final entry = WordEntry(
        id: now.microsecondsSinceEpoch.toString(),
        word: word,
        translation: result.primary,
        createdAt: now,
        sourceLanguage: source,
      );
      final saved = await _saveCollection([
        ..._words,
        entry,
      ], page: _words.length ~/ _wordsPerPage);
      if (saved) _input.clear();
    } on TranslationException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _editTranslation(WordEntry entry) async {
    if (_busy) return;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => TranslationEditor(
        word: entry.word,
        translation: entry.translation,
        sourceLanguage: entry.sourceLanguage ?? _sourceLanguage,
        allowDirectionChange: entry.sourceLanguage == null,
        service: _translationService,
      ),
    );
    if (!mounted || result == null || result == entry.translation) return;
    await _saveCollection([
      for (final word in _words)
        word.id == entry.id ? word.withTranslation(result) : word,
    ]);
  }

  Future<void> _swapLanguages() async {
    if (_busy) return;
    final source = _targetLanguage;
    Navigator.pop(context);
    setState(() => _sourceLanguage = source);
    await _repository.saveSourceLanguage(source);
  }

  Future<void> _clearWords() async {
    if (_busy) return;
    Navigator.pop(context);
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear your collection?'),
        content: const Text('This removes every saved word from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (clear == true && mounted) await _saveCollection([], page: 0);
  }

  Future<void> _startPractice() async {
    if (_busy || _words.isEmpty) return;
    _inputFocus.unfocus();
    Navigator.pop(context);
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PracticeScreen(words: _words)),
    );
    if (mounted && completed == true) _showMessage('Practice complete.');
  }

  void _showHelp() {
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('How it works'),
        content: const Text(
          'New translations stay visible for five seconds. Rub across a '
          'hidden translation to reveal it. While it is visible, hold the '
          'word or translation for two seconds to edit it or look up other '
          'meanings.\n\n'
          'In Practice mode, type each translation. A round restarts after '
          'three mistakes on one word or if you exceed your reveal allowance. '
          'You get one reveal per eight words, rounded up.\n\n'
          'Online lookups send the word and its language to Wiktapi. The '
          'offline dictionary uses Wiktionary data via Kaikki.org and DBnary, '
          'ranked with FrequencyWords (CC BY-SA 4.0). FreeDict supplements it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: LibraryPage(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 360;
            return Column(
              children: [
                LibraryHeading(
                  title: 'Word Collector',
                  leading: IconButton(
                    tooltip: 'Open menu',
                    onPressed: _busy
                        ? null
                        : () {
                            _inputFocus.unfocus();
                            _scaffoldKey.currentState?.openDrawer();
                          },
                    icon: const Icon(Icons.menu),
                  ),
                  detail: _direction.toUpperCase(),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildPage(compact),
                ),
                _buildInput(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPage(bool compact) {
    final start = _page * _wordsPerPage;
    final count = math.min(_wordsPerPage, _words.length - start);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _words.length == 1
                          ? '1 saved word'
                          : '${_words.length} saved words',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (count > 0)
                    const Row(
                      children: [
                        Icon(Icons.gesture, size: 16, color: libraryMuted),
                        SizedBox(width: 5),
                        Text('Rub to reveal', style: libraryLabel),
                      ],
                    ),
                ],
              ),
            ),
          Expanded(
            child: count == 0
                ? const _EmptyCollection()
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: libraryRule),
                    ),
                    child: Column(
                      children: [
                        if (!compact) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('WORD', style: libraryLabel),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'TRANSLATION',
                                    style: libraryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                        Expanded(
                          child: ListView.separated(
                            key: PageStorageKey(_page),
                            padding: EdgeInsets.zero,
                            itemCount: count,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = _words[start + index];
                              return WordRow(
                                key: ValueKey(entry.id),
                                entry: entry,
                                onEdit: () => _editTranslation(entry),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (!compact || _pageCount > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
          icon: const Icon(Icons.arrow_back),
        ),
        Text('${_page + 1} / $_pageCount', style: libraryLabel),
        IconButton(
          tooltip: 'Next page',
          onPressed: _page < _pageCount - 1
              ? () => setState(() => _page++)
              : null,
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: TextField(
        controller: _input,
        focusNode: _inputFocus,
        enabled: !_loading,
        readOnly: _busy,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        onSubmitted: (_) => _addWord(),
        decoration: InputDecoration(
          hintText: _translating
              ? 'Looking up word…'
              : 'Add ${_sourceLanguage == 'hu' ? 'a Hungarian' : 'an English'} word…',
          suffixIcon: _translating
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Add word',
                  onPressed: _busy ? null : _addWord,
                  icon: const Icon(Icons.add),
                ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: Text(
                'Word Collector',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1, thickness: 2, color: libraryInk),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Practice mode'),
              subtitle: _words.isEmpty
                  ? const Text('Add a word to start')
                  : null,
              enabled: !_busy && _words.isNotEmpty,
              onTap: _startPractice,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translation direction'),
              subtitle: Text(_direction),
              trailing: const Icon(Icons.swap_horiz),
              enabled: !_busy,
              onTap: _swapLanguages,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('How it works'),
              onTap: _showHelp,
            ),
            if (_words.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear collection'),
                enabled: !_busy,
                onTap: _clearWords,
              ),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: Text('Version 0.1.2', style: libraryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(border: Border.all(color: libraryRule)),
          child: Column(
            children: [
              const Icon(
                Icons.auto_stories_outlined,
                size: 30,
                color: libraryAccent,
              ),
              const SizedBox(height: 10),
              Text(
                'Collect your first word',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Add a Hungarian or English word below to save its translation.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
