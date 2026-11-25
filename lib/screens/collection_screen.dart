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
  final _listKey = GlobalKey<ReorderableListState>();
  final _scroll = ScrollController(keepScrollOffset: false);
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  List<WordEntry> _words = [];
  int _page = 0;
  double _minimumRowHeight = 32;
  double? _listViewport;
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
    _scroll.addListener(_syncPage);
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
    _jumpAfterLayout(_page);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _minimumRowHeight = WordRow.minimumHeight(MediaQuery.textScalerOf(context));
  }

  double _rowHeight(double viewport) =>
      math.max(_minimumRowHeight, viewport / _wordsPerPage);

  void _syncPage() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final extent = _rowHeight(_scroll.position.viewportDimension);
    final page = ((_scroll.offset + 0.5) ~/ (extent * _wordsPerPage)).clamp(
      0,
      _pageCount - 1,
    );
    if (page != _page) setState(() => _page = page);
  }

  void _jumpAfterLayout(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _goToPage(page, jump: true);
    });
  }

  void _goToPage(int page, {bool jump = false}) {
    if (!_scroll.hasClients) return;
    final extent = _rowHeight(_scroll.position.viewportDimension);
    final offset = (page * _wordsPerPage * extent).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (jump) {
      _scroll.jumpTo(offset);
    } else {
      _listKey.currentState?.cancelReorder();
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
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
        _page = math.min(page ?? _page, _pageCount - 1);
      });
      if (page != null) _jumpAfterLayout(_page);
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
    _listKey.currentState?.cancelReorder();
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

  Future<void> _editWord(WordEntry entry, {required bool editWord}) async {
    if (_busy) return;
    _listKey.currentState?.cancelReorder();
    final result = await showDialog<WordEdits>(
      context: context,
      builder: (context) => TranslationEditor(
        word: entry.word,
        translation: entry.translation,
        sourceLanguage: entry.sourceLanguage ?? _sourceLanguage,
        allowDirectionChange: entry.sourceLanguage == null,
        service: _translationService,
        editWord: editWord,
      ),
    );
    if (!mounted ||
        result == null ||
        (result.word == entry.word &&
            result.translation == entry.translation)) {
      return;
    }
    await _saveCollection([
      for (final word in _words)
        word.id == entry.id
            ? word.withEdits(word: result.word, translation: result.translation)
            : word,
    ]);
  }

  Future<void> _deleteWord(WordEntry entry) async {
    if (_busy) return;
    _listKey.currentState?.cancelReorder();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${entry.word}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _saveCollection(_words.where((word) => word.id != entry.id).toList());
  }

  void _reorderWords(int from, int to) {
    if (_busy || from == to) return;
    final words = List.of(_words);
    words.insert(to, words.removeAt(from));
    _saveCollection(words);
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
    _listKey.currentState?.cancelReorder();
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
    _listKey.currentState?.cancelReorder();
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
          'hidden translation to reveal it for five seconds. Hold a visible '
          'translation for two seconds to edit it. Tap the three dots to edit '
          'or delete a word. Hold a word or a covered area in its row for 1.5 '
          'seconds, then drag to reorder it.\n\n'
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
            final compact = constraints.maxHeight < 720;
            return Column(
              children: [
                LibraryHeading(
                  title: 'Word Collector',
                  compact: compact,
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
                      ? const LibraryInk(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _buildPage(
                          compact,
                          showLabels: constraints.maxHeight >= 510,
                          showPagination: constraints.maxHeight >= 360,
                        ),
                ),
                _buildInput(compact),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPage(
    bool compact, {
    required bool showLabels,
    required bool showPagination,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (!compact)
            LibraryInk(
              child: Padding(
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
                    if (_words.isNotEmpty)
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
            ),
          Expanded(
            child: _words.isEmpty
                ? const _EmptyCollection()
                : LibraryFrame(
                    child: Column(
                      children: [
                        if (showLabels) ...[
                          const LibraryInk(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 5,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: WordRow.menuWidth,
                                      ),
                                      child: Text('WORD', style: libraryLabel),
                                    ),
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
                          ),
                          const LibraryRuleLine(),
                        ],
                        Expanded(child: LibraryInk(child: _buildWordList())),
                      ],
                    ),
                  ),
          ),
          if (showPagination || _pageCount > 1)
            LibraryInk(child: _buildPagination()),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = _rowHeight(constraints.maxHeight);
        final wordsOnLastPage =
            _words.length - (_pageCount - 1) * _wordsPerPage;
        // Leave room to scroll the last group of words to the top of the list.
        final endPadding = _pageCount > 1
            ? math.max(0.0, constraints.maxHeight - wordsOnLastPage * rowHeight)
            : 0.0;
        return NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth != 0) return false;
            final viewport = notification.metrics.viewportDimension;
            final previous = _listViewport;
            _listViewport = viewport;
            if (previous != null && viewport != previous && viewport > 0) {
              _goToPage(_page, jump: true);
            }
            return false;
          },
          child: ReorderableList(
            key: _listKey,
            controller: _scroll,
            itemCount: _words.length,
            itemExtent: rowHeight,
            padding: EdgeInsets.only(bottom: endPadding),
            onReorderItem: _reorderWords,
            proxyDecorator: (child, _, _) =>
                Material(color: libraryPaper, elevation: 4, child: child),
            itemBuilder: (context, index) {
              final entry = _words[index];
              return WordRow(
                key: ValueKey(entry.id),
                entry: entry,
                index: index,
                height: rowHeight,
                enabled: !_busy,
                onEditWord: () => _editWord(entry, editWord: true),
                onEditTranslation: () => _editWord(entry, editWord: false),
                onDelete: () => _deleteWord(entry),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: _page > 0 ? () => _goToPage(_page - 1) : null,
          icon: const Icon(Icons.arrow_back),
        ),
        Text('${_page + 1} / $_pageCount', style: libraryLabel),
        IconButton(
          tooltip: 'Next page',
          onPressed: _page < _pageCount - 1 ? () => _goToPage(_page + 1) : null,
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
    );
  }

  Widget _buildInput(bool compact) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: LibraryFrame(
        child: LibraryInk(
          child: TextField(
            controller: _input,
            focusNode: _inputFocus,
            enabled: !_loading,
            readOnly: _busy,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onSubmitted: (_) => _addWord(),
            decoration: InputDecoration(
              isDense: compact,
              contentPadding: compact
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
                  : null,
              suffixIconConstraints: compact
                  ? const BoxConstraints.tightFor(width: 44, height: 40)
                  : null,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: _translating
                  ? 'Looking up word…'
                  : 'Add ${_sourceLanguage == 'hu' ? 'a Hungarian' : 'an English'} word…',
              suffixIcon: _translating
                  ? const Padding(
                      padding: EdgeInsets.all(11),
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
        child: LibraryFrame(
          child: LibraryInk(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
        ),
      ),
    );
  }
}
