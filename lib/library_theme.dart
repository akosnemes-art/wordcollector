import 'package:flutter/material.dart';

const libraryInk = Color(0xFF282722);
const libraryPaper = Color(0xFFFCF9F1);
const libraryCanvas = Color(0xFFF0EBDE);
const libraryRule = Color(0xFFCCC3AF);
const libraryMuted = Color(0xFF645E51);
const libraryAccent = Color(0xFF653A30);
const librarySerif = 'Noto Serif Display';

ThemeData libraryTheme() {
  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: libraryRule),
  );
  const buttonShape = RoundedRectangleBorder();

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: libraryAccent,
      surface: libraryPaper,
      primary: libraryAccent,
      onSurface: libraryInk,
      outline: libraryMuted,
      outlineVariant: libraryRule,
    ),
    scaffoldBackgroundColor: libraryCanvas,
    dividerTheme: const DividerThemeData(color: libraryRule, thickness: 1),
    drawerTheme: const DrawerThemeData(
      backgroundColor: libraryPaper,
      shape: buttonShape,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: libraryPaper,
      shape: RoundedRectangleBorder(side: BorderSide(color: libraryRule)),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily: librarySerif,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.12,
      ),
      titleLarge: TextStyle(
        fontFamily: librarySerif,
        fontSize: 23,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: libraryInk, fontSize: 16, height: 1.4),
      bodyMedium: TextStyle(color: libraryMuted, fontSize: 14, height: 1.4),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: libraryPaper,
      hintStyle: TextStyle(color: libraryMuted),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: libraryAccent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        side: const BorderSide(color: libraryRule),
      ),
    ),
  );
}

const libraryLabel = TextStyle(
  color: libraryMuted,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.5,
);

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: libraryPaper,
                border: Border.all(color: libraryRule),
                boxShadow: const [
                  BoxShadow(color: Color(0x10000000), offset: Offset(2, 3)),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryHeading extends StatelessWidget {
  const LibraryHeading({
    super.key,
    required this.title,
    required this.leading,
    required this.detail,
  });

  final String title;
  final Widget leading;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(child: Text(detail, style: libraryLabel)),
            ],
          ),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Divider(height: 3, thickness: 2, color: libraryInk),
          const SizedBox(height: 2),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
