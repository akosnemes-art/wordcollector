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
    required this.height,
    required this.enabled,
    required this.onEditWord,
    required this.onEditTranslation,
    required this.onDelete,
  });

  final WordEntry entry;
  final int index;
  final double height;
  final bool enabled;
  final VoidCallback onEditWord;
  final VoidCallback onEditTranslation;
  final VoidCallback onDelete;

  static const menuWidth = 44.0;
  static const _languageSize = 9.0;
  static const _compactSize = 15.0;
  static const _regularSize = 17.0;

  static double minimumHeight(TextScaler scale) =>
      (scale.scale(_compactSize) * 1.16 + scale.scale(_languageSize) * 1.12 + 5)
          .clamp(32.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final language = entry.sourceLanguage;
    final scale = MediaQuery.textScalerOf(context);
    final expanded =
        height >=
        2 * scale.scale(_regularSize) * 1.16 +
            scale.scale(_languageSize) * 1.12 +
            9;
    final fontSize = expanded ? _regularSize : _compactSize;

    Widget dragTarget(Widget child, bool available) => _WordDragHandle(
      index: index,
      enabled: enabled && available,
      child: child,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: libraryRule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: ScratchTranslation(
          translation: entry.translation,
          createdAt: entry.createdAt,
          onEdit: enabled ? onEditTranslation : null,
          dragTarget: dragTarget,
          compact: !expanded,
          word: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: menuWidth,
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
                child: dragTarget(
                  Container(
                    color: Colors.transparent,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.word,
                          maxLines: expanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: librarySerif,
                            fontSize: fontSize,
                            height: 1.16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (language != null)
                          Text(
                            language.toUpperCase(),
                            style: libraryLabel.copyWith(
                              fontSize: _languageSize,
                              height: 1.12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  true,
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
