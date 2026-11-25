import 'package:flutter/material.dart';

import '../services/translation_service.dart';

Future<String?> chooseTranslation(
  BuildContext context, {
  required String word,
  required TranslationResult result,
}) async {
  final options = result.options;
  if (options.length == 1 && !result.isOnline) return options.single;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(
        result.isOnline
            ? 'Check the online translation for “$word”'
            : 'Choose a translation for “$word”',
      ),
      children: [
        for (final option in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option),
            child: Text(option),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class TranslationEditor extends StatefulWidget {
  const TranslationEditor({
    super.key,
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.allowDirectionChange,
    required this.service,
  });

  final String word;
  final String translation;
  final String sourceLanguage;
  final bool allowDirectionChange;
  final TranslationService service;

  @override
  State<TranslationEditor> createState() => _TranslationEditorState();
}

class _TranslationEditorState extends State<TranslationEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _input = TextEditingController(text: widget.translation);
  late var _source = widget.sourceLanguage;
  bool _lookingUp = false;
  String? _lookupError;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _input.text.trim());
    }
  }

  Future<void> _lookUp() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _lookingUp = true;
      _lookupError = null;
    });
    try {
      final result = await widget.service.translate(
        widget.word,
        sourceLanguage: _source,
        targetLanguage: _source == 'hu' ? 'en' : 'hu',
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final selection = await chooseTranslation(
        context,
        word: widget.word,
        result: result,
      );
      if (mounted && selection != null) _input.text = selection;
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
      title: const Text('Edit translation'),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              autofocus: true,
              controller: _input,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: widget.word),
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
