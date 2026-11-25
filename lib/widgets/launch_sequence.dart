import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../library_theme.dart';
import 'credit_floral_frame.dart';

class LaunchSequence extends StatefulWidget {
  const LaunchSequence({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchSequence> createState() => _LaunchSequenceState();
}

class _LaunchSequenceState extends State<LaunchSequence>
    with SingleTickerProviderStateMixin {
  static const _splashEnds = 3000 / 4450;
  static const _splashFadeEnds = 3450 / 4450;

  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4450),
    animationBehavior: AnimationBehavior.preserve,
  )..forward();
  late final Animation<double> _splashOpacity = _timeline
      .drive(CurveTween(curve: const Interval(_splashEnds, _splashFadeEnds)))
      .drive(Tween<double>(begin: 1, end: 0));
  late final Animation<double> _flowers = _timeline.drive(
    CurveTween(curve: const Interval(120 / 4450, 2700 / 4450)),
  );
  late final Animation<double> _rules = _timeline.drive(
    CurveTween(
      curve: const Interval(
        3280 / 4450,
        4050 / 4450,
        curve: Curves.easeInOutCubic,
      ),
    ),
  );
  late final Animation<double> _ink = _timeline.drive(
    CurveTween(curve: const Interval(4050 / 4450, 1, curve: Curves.easeOut)),
  );

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _timeline,
      child: LibraryEntrance(
        rules: reduceMotion ? kAlwaysCompleteAnimation : _rules,
        ink: reduceMotion ? kAlwaysCompleteAnimation : _ink,
        child: widget.child,
      ),
      builder: (context, child) {
        final ready = reduceMotion
            ? _timeline.value >= _splashEnds
            : _timeline.isCompleted;
        final showSplash =
            _timeline.value < (reduceMotion ? _splashEnds : _splashFadeEnds);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: !ready,
              child: ExcludeSemantics(
                excluding: !ready,
                child: ExcludeFocus(excluding: !ready, child: child!),
              ),
            ),
            if (showSplash)
              FadeTransition(
                opacity: reduceMotion
                    ? kAlwaysCompleteAnimation
                    : _splashOpacity,
                child: _DesignerSplash(
                  growth: reduceMotion ? kAlwaysCompleteAnimation : _flowers,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DesignerSplash extends StatelessWidget {
  const _DesignerSplash({required this.growth});

  final Animation<double> growth;

  @override
  Widget build(BuildContext context) {
    final caption = libraryLabel.copyWith(fontFamily: librarySerif);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Material(
        key: const ValueKey('designer-splash'),
        color: libraryPaper,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: CreditFloralFrame(
                growth: growth,
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Designed by', style: caption),
                      const SizedBox(height: 8),
                      Text(
                        designerName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium!
                            .copyWith(
                              fontSize: math.min(
                                42,
                                constraints.maxWidth * 0.174,
                              ),
                            ),
                      ),
                      const SizedBox(height: 13),
                      const SizedBox(
                        width: 52,
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: libraryAccent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Version $appVersion', style: caption),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
