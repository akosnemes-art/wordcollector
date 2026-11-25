import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../library_theme.dart';
import '../models/word_entry.dart';
import 'scratch_translation.dart';

class WordRow extends StatelessWidget {
  const WordRow({
    super.key,
    required this.entry,
    required this.index,
    required this.enabled,
    required this.onEditWord,
    required this.onEditTranslation,
    required this.onDelete,
  });

  final WordEntry entry;
  final int index;
  final bool enabled;
  final VoidCallback onEditWord;
  final VoidCallback onEditTranslation;
  final VoidCallback onDelete;

  static const menuWidth = 48.0;

  @override
  Widget build(BuildContext context) {
    final language = entry.sourceLanguage;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: libraryRule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: ScratchTranslation(
          translation: entry.translation,
          createdAt: entry.createdAt,
          onEdit: enabled ? onEditTranslation : null,
          word: Row(
            children: [
              SizedBox(
                width: menuWidth,
                height: 48,
                child: PopupMenuButton<_WordAction>(
                  enabled: enabled,
                  tooltip: 'Options for ${entry.word}',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 19,
                    color: libraryMuted,
                  ),
                  onSelected: (action) => switch (action) {
                    _WordAction.edit => onEditWord(),
                    _WordAction.delete => onDelete(),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _WordAction.edit,
                      child: Text('Edit word'),
                    ),
                    PopupMenuItem(
                      value: _WordAction.delete,
                      child: Text('Delete word'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _WordDragHandle(
                  index: index,
                  enabled: enabled,
                  child: Container(
                    color: Colors.transparent,
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(minHeight: 42),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.word,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: librarySerif,
                            fontSize: 19,
                            height: 1.18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (language != null)
                          Text(
                            language.toUpperCase(),
                            style: libraryLabel.copyWith(height: 1.2),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _WordAction { edit, delete }

class _WordDragHandle extends ReorderableDragStartListener {
  const _WordDragHandle({
    required super.index,
    required super.enabled,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(
        delay: const Duration(milliseconds: 1500),
        debugOwner: this,
      );
}
