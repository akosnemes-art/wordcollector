import 'package:flutter/material.dart';

import '../library_theme.dart';
import '../models/word_entry.dart';
import 'scratch_translation.dart';

class WordRow extends StatelessWidget {
  const WordRow({super.key, required this.entry, required this.onEdit});

  final WordEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final language = entry.sourceLanguage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: ScratchTranslation(
        translation: entry.translation,
        createdAt: entry.createdAt,
        onEdit: onEdit,
        word: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.word,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: librarySerif,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (language != null)
              Text(language.toUpperCase(), style: libraryLabel),
          ],
        ),
      ),
    );
  }
}
