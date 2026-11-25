import 'package:flutter/material.dart';

import '../services/translation_service.dart';

typedef WordEdits = ({String word, String translation});

class TranslationEditor extends StatefulWidget {
  const TranslationEditor({
    super.key,
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.allowDirectionChange,
    required this.service,
    this.editWord = false,
  });

  final String word;
  final String translation;
  final String sourceLanguage;
  final bool allowDirectionChange;
  final TranslationService service;
  final bool editWord;

  @override
  State<TranslationEditor> createState() => _TranslationEditorState();
}

class _TranslationEditorState extends State<TranslationEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _wordInput = TextEditingController(text: widget.word);
  late final _input = TextEditingController(text: widget.translation);
  late var _source = widget.sourceLanguage;
  bool _lookingUp = false;
  String? _lookupError;
  List<String> _alternatives = const [];

  @override
  void dispose() {
    _wordInput.dispose();
    _input.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, (
        word: _wordInput.text.trim(),
        translation: _input.text.trim(),
      ));
    }
  }

  Future<void> _lookUp() async {
    final word = _wordInput.text.trim();
    if (word.isEmpty) {
      _formKey.currentState!.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _lookingUp = true;
      _lookupError = null;
      _alternatives = const [];
    });
    try {
      final result = await widget.service.translate(
        word,
        sourceLanguage: _source,
        targetLanguage: _source == 'hu' ? 'en' : 'hu',
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      _input.text = result.primary;
      setState(() => _alternatives = result.options.skip(1).take(5).toList());
    } on TranslationException catch (error) {
      if (mounted) setState(() => _lookupError = error.message);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.editWord ? 'Edit word' : 'Edit translation'),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.editWord) ...[
              TextFormField(
                autofocus: true,
                controller: _wordInput,
                readOnly: _lookingUp,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Word'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a word.'
                    : null,
                onChanged: (_) {
                  if (_alternatives.isEmpty && _lookupError == null) return;
                  setState(() {
                    _alternatives = const [];
                    _lookupError = null;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              autofocus: !widget.editWord,
              readOnly: _lookingUp,
              controller: _input,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: widget.editWord ? 'Translation' : widget.word,
              ),
              onFieldSubmitted: (_) => _save(),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a translation.'
                  : null,
            ),
            if (widget.allowDirectionChange)
              DropdownButton<String>(
                value: _source,
                onChanged: _lookingUp
                    ? null
                    : (value) => setState(() => _source = value!),
                items: const [
                  DropdownMenuItem(
                    value: 'hu',
                    child: Text('Hungarian → English'),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text('English → Hungarian'),
                  ),
                ],
              ),
            TextButton.icon(
              onPressed: _lookingUp ? null : _lookUp,
              icon: const Icon(Icons.search),
              label: Text(_lookingUp ? 'Looking up…' : 'Look up translation'),
            ),
            if (_alternatives.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  for (final meaning in _alternatives)
                    ActionChip(
                      label: Text(meaning),
                      onPressed: () => _input.text = meaning,
                    ),
                ],
              ),
            if (_lookupError case final message?) Text(message),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
