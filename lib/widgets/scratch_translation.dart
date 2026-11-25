import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../library_theme.dart';

class ScratchTranslation extends StatefulWidget {
  const ScratchTranslation({
    super.key,
    required this.translation,
    required this.createdAt,
    this.word,
    this.onEdit,
  });

  final String translation;
  final DateTime createdAt;
  final Widget? word;
  final VoidCallback? onEdit;

  @override
  State<ScratchTranslation> createState() => _ScratchTranslationState();
}

class _ScratchTranslationState extends State<ScratchTranslation> {
  static const _initialRevealTime = Duration(seconds: 5);
  static const _scratchRevealTime = Duration(seconds: 3);
  static const _editHoldTime = Duration(seconds: 3);
  static const _rubDistance = 150.0;

  Timer? _hideTimer;
  DateTime? _hideAt;
  double _reveal = 1;
  double _rubbedDistance = 0;
  bool _isFading = false;
  bool _holdingVisibleWord = false;

  @override
  void initState() {
    super.initState();
    final age = DateTime.now().difference(widget.createdAt);
    final remaining = _initialRevealTime - age;
    if (remaining <= Duration.zero) {
      _reveal = 0;
    } else {
      _scheduleHide(remaining);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide(Duration delay) {
    _hideTimer?.cancel();
    _hideAt = DateTime.now().add(delay);
    _hideTimer = Timer(delay, _hide);
  }

  void _hide() {
    setState(() {
      _isFading = true;
      _reveal = 0;
      _rubbedDistance = 0;
    });
  }

  void _rub(DragUpdateDetails details) {
    if (_reveal == 1) return;
    _hideTimer?.cancel();
    _rubbedDistance += details.delta.distance;
    setState(() {
      _isFading = false;
      _reveal = (_rubbedDistance / _rubDistance).clamp(0, 1);
    });
  }

  void _finishRub() {
    if (_rubbedDistance == 0) return;
    if (_reveal >= 0.72) {
      _showTranslation();
    } else {
      _scheduleHide(const Duration(milliseconds: 500));
    }
  }

  void _showTranslation() {
    setState(() {
      _isFading = false;
      _reveal = 1;
      _rubbedDistance = 0;
    });
    _scheduleHide(_scratchRevealTime);
  }

  void _beginHold(LongPressDownDetails details) {
    _holdingVisibleWord = _reveal == 1;
    if (_holdingVisibleWord) _hideTimer?.cancel();
  }

  void _cancelHold() {
    if (!_holdingVisibleWord) return;
    _holdingVisibleWord = false;
    final remaining = _hideAt?.difference(DateTime.now()) ?? Duration.zero;
    _scheduleHide(remaining);
  }

  void _editVisibleWord() {
    _scheduleHide(_scratchRevealTime);
    widget.onEdit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fullyVisible = _reveal == 1;
    final translation = Semantics(
      label: fullyVisible
          ? 'Translation: ${widget.translation}'
          : 'Hidden translation. Rub to reveal it.',
      customSemanticsActions: {
        if (!fullyVisible)
          const CustomSemanticsAction(label: 'Reveal translation'):
              _showTranslation,
        if (fullyVisible && widget.onEdit != null)
          const CustomSemanticsAction(label: 'Edit translation'):
              _editVisibleWord,
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _rub,
          onHorizontalDragEnd: (_) => _finishRub(),
          onHorizontalDragCancel: _finishRub,
          child: Container(
            constraints: const BoxConstraints(minHeight: 42),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Color.lerp(libraryCanvas, libraryPaper, _reveal),
              border: Border.all(
                color: libraryRule.withValues(alpha: (1 - _reveal) * 0.6),
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (_reveal == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9),
                    child: Icon(Icons.gesture, size: 16, color: libraryMuted),
                  ),
                AnimatedOpacity(
                  opacity: _reveal,
                  duration: _isFading
                      ? const Duration(milliseconds: 650)
                      : const Duration(milliseconds: 60),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    child: Text(
                      widget.translation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: libraryAccent,
                        fontFamily: librarySerif,
                        fontSize: 17,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final word = widget.word;
    final row = word == null
        ? translation
        : Row(
            children: [
              Expanded(child: word),
              const SizedBox(width: 12),
              Expanded(child: translation),
            ],
          );
    if (widget.onEdit == null) return row;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: _editHoldTime),
              (recognizer) {
                recognizer.onLongPressDown = _beginHold;
                recognizer.onLongPressCancel = _cancelHold;
                recognizer.onLongPress = () {
                  if (!_holdingVisibleWord) return;
                  _holdingVisibleWord = false;
                  _editVisibleWord();
                };
              },
            ),
      },
      child: row,
    );
  }
}
