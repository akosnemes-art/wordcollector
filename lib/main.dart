import 'package:flutter/material.dart';

import 'library_theme.dart';
import 'screens/collection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WordCollectorApp());
}

class WordCollectorApp extends StatelessWidget {
  const WordCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Collector',
      debugShowCheckedModeBanner: false,
      theme: libraryTheme(),
      home: const CollectionScreen(),
    );
  }
}
