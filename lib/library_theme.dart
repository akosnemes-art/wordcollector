import 'package:flutter/material.dart';

import 'app_info.dart';

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
    popupMenuTheme: const PopupMenuThemeData(
      color: libraryPaper,
      shape: RoundedRectangleBorder(side: BorderSide(color: libraryRule)),
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
            child: LibraryFrame(
              fill: libraryPaper,
              shadow: true,
              child: Column(
                children: [
                  Expanded(child: child),
                  const LibraryInk(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text('Version $appVersion', style: libraryLabel),
                    ),
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

class LibraryHeading extends StatelessWidget {
  const LibraryHeading({
    super.key,
    required this.title,
    required this.leading,
    required this.detail,
    this.compact = false,
  });

  final String title;
  final Widget leading;
  final String detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineMedium;
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(9, 5, 12, 0)
          : const EdgeInsets.fromLTRB(16, 9, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            LibraryInk(
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: titleStyle?.copyWith(fontSize: 25),
                          ),
                        ),
                        Text(detail, style: libraryLabel.copyWith(fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            LibraryInk(
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 8),
                  Expanded(child: Text(detail, style: libraryLabel)),
                ],
              ),
            ),
            LibraryInk(child: Text(title, style: titleStyle)),
          ],
          SizedBox(height: compact ? 4 : 12),
          const LibraryRuleLine(height: 3, thickness: 2, color: libraryInk),
          const SizedBox(height: 2),
          const LibraryRuleLine(),
        ],
      ),
    );
  }
}

class LibraryEntrance extends InheritedWidget {
  const LibraryEntrance({
    super.key,
    required this.rules,
    required this.ink,
    required super.child,
  });

  final Animation<double> rules;
  final Animation<double> ink;

  static LibraryEntrance? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryEntrance>();

  @override
  bool updateShouldNotify(LibraryEntrance oldWidget) =>
      rules != oldWidget.rules || ink != oldWidget.ink;
}

class LibraryInk extends StatelessWidget {
  const LibraryInk({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ink = LibraryEntrance.of(context)?.ink;
    return ink == null ? child : FadeTransition(opacity: ink, child: child);
  }
}

class LibraryFrame extends StatelessWidget {
  const LibraryFrame({
    super.key,
    this.fill,
    this.shadow = false,
    required this.child,
  });

  final Color? fill;
  final bool shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rules = LibraryEntrance.of(context)?.rules;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: rules == null ? Border.all(color: libraryRule) : null,
        boxShadow: shadow
            ? const [BoxShadow(color: Color(0x10000000), offset: Offset(2, 3))]
            : null,
      ),
      child: rules == null
          ? child
          : CustomPaint(
              foregroundPainter: _LibraryRulePainter(
                rules,
                libraryRule,
                1,
                frame: true,
              ),
              child: child,
            ),
    );
  }
}

class LibraryRuleLine extends StatelessWidget {
  const LibraryRuleLine({
    super.key,
    this.height = 1,
    this.thickness = 1,
    this.color = libraryRule,
  });

  final double height;
  final double thickness;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rules = LibraryEntrance.of(context)?.rules;
    if (rules == null) {
      return Divider(height: height, thickness: thickness, color: color);
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _LibraryRulePainter(rules, color, thickness)),
    );
  }
}

class _LibraryRulePainter extends CustomPainter {
  _LibraryRulePainter(
    this.progress,
    this.color,
    this.thickness, {
    this.frame = false,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double thickness;
  final bool frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress.value == 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    if (frame) {
      final path = Path()..addRect((Offset.zero & size).deflate(thickness / 2));
      if (progress.value == 1) {
        canvas.drawPath(path, paint);
      } else {
        final outline = path.computeMetrics().first;
        canvas.drawPath(
          outline.extractPath(0, outline.length * progress.value),
          paint,
        );
      }
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width * progress.value, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LibraryRulePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      thickness != oldDelegate.thickness ||
      frame != oldDelegate.frame;
}
