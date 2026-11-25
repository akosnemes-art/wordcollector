import 'dart:math' as math;

import 'package:flutter/material.dart';

class CreditFloralFrame extends StatelessWidget {
  const CreditFloralFrame({
    super.key,
    required this.growth,
    required this.child,
  });

  final Animation<double> growth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 408),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return SizedBox(
            width: width,
            child: CustomPaint(
              painter: _BotanicalPainter(growth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.16,
                  vertical: width * 0.18,
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BotanicalPainter extends CustomPainter {
  _BotanicalPainter(this.growth) : super(repaint: growth);

  final Animation<double> growth;

  static const _stem = Color(0xFF52684C);
  static const _vein = Color(0xFF577056);
  static const _sage = Color(0xFFB4BE98);
  static const _olive = Color(0xFF99AA77);
  static const _rose = Color(0xFFD4939E);
  static const _wine = Color(0xFF8B455D);
  static const _lilac = Color(0xFFC6A8C1);
  static const _plum = Color(0xFF785A80);
  static const _honey = Color(0xFFAA7647);

  static final _mainVine = Path()
    ..moveTo(20, 91)
    ..cubicTo(59, 107, 112, 102, 136, 65)
    ..cubicTo(156, 37, 165, 1, 156, -30)
    ..cubicTo(148, -61, 130, -79, 140, -96)
    ..cubicTo(145, -106, 158, -106, 165, -98);
  static final _lowerSprig = Path()
    ..moveTo(72, 98)
    ..cubicTo(78, 100, 99, 111, 121, 108);
  static final _sideSprig = Path()
    ..moveTo(137, 64)
    ..cubicTo(149, 66, 163, 51, 165, 35);
  static final _upperSprig = Path()
    ..moveTo(154, -38)
    ..cubicTo(160, -48, 174, -51, 175, -67);
  static final _innerSprig = Path()
    ..moveTo(143, -61)
    ..cubicTo(137, -65, 129, -63, 125, -73)
    ..cubicTo(122, -82, 115, -84, 107, -88);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || growth.value == 0) return;
    final scale = math.min(size.width / 374, size.height / 256);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale, scale);
    _spray(canvas, reverse: false);
    canvas.scale(-1, 1);
    _spray(canvas, reverse: true);
    canvas.restore();
  }

  double _phase(double start, double end) => Curves.easeOutCubic.transform(
    ((growth.value - start) / (end - start)).clamp(0.0, 1.0),
  );

  void _spray(Canvas canvas, {required bool reverse}) {
    canvas.save();
    if (reverse) canvas.translate(1, -3);
    _trace(canvas, _mainVine, _phase(0, 0.88), width: 1.1);
    _trace(canvas, _lowerSprig, _phase(0.14, 0.48));
    _trace(canvas, _sideSprig, _phase(0.29, 0.64));
    _trace(canvas, _upperSprig, _phase(0.49, 0.81));
    _trace(canvas, _innerSprig, _phase(0.55, 0.86));

    const leaves = [
      (Offset(46, 98), -1.02, 19.0, 6.0, 0.13),
      (Offset(61, 100), 0.98, 21.0, 7.0, 0.18),
      (Offset(81, 98), -1.10, 24.0, 7.5, 0.21),
      (Offset(111, 86), 0.15, 23.0, 7.0, 0.31),
      (Offset(125, 77), -2.39, 24.0, 7.5, 0.34),
      (Offset(148, 44), 0.0, 22.0, 6.0, 0.37),
      (Offset(154, 29), -2.15, 22.0, 7.0, 0.41),
      (Offset(159, 4), -0.73, 20.0, 6.3, 0.46),
      (Offset(158, -13), -2.50, 26.0, 7.0, 0.49),
      (Offset(154, -38), -1.10, 16.0, 5.0, 0.56),
      (Offset(148, -52), -2.45, 17.0, 5.3, 0.60),
      (Offset(140, -71), -0.75, 16.0, 5.3, 0.66),
      (Offset(136, -82), -2.72, 18.0, 5.3, 0.73),
      (Offset(144, -100), -2.20, 13.0, 4.0, 0.77),
      (Offset(125, -73), -2.98, 13.0, 4.0, 0.69),
    ];
    for (var i = 0; i < leaves.length; i++) {
      final (position, angle, length, width, start) = leaves[i];
      _leaf(
        canvas,
        position,
        angle,
        length,
        width,
        i.isEven ? _sage : _olive,
        _phase(start, start + 0.23),
      );
    }

    _flower(
      canvas,
      const Offset(166, 35),
      reverse ? 10.5 : 13.0,
      _phase(0.49, 0.79),
      reverse ? _lilac : _rose,
      reverse ? _plum : _wine,
      reverse ? 6 : 5,
    );
    _flower(
      canvas,
      const Offset(151, -49),
      reverse ? 16.5 : 14.0,
      _phase(0.61, 0.97),
      reverse ? _rose : _lilac,
      reverse ? _wine : _plum,
      6,
    );
    _flower(
      canvas,
      const Offset(107, -88),
      7.4,
      _phase(0.71, 0.96),
      const Color(0xFFE1B58D),
      _honey,
      5,
    );
    _flower(
      canvas,
      const Offset(165, -98),
      8.6,
      _phase(0.79, 1),
      _rose,
      _wine,
      5,
    );
    _bud(canvas, const Offset(175, -67), -0.7, _phase(0.67, 0.94), _wine);
    _bud(canvas, const Offset(121, 108), 0.6, _phase(0.42, 0.65), _plum);
    _bud(canvas, const Offset(145, 85), 1.2, _phase(0.52, 0.8), _honey);

    for (final (position, size, start) in const [
      (Offset(155, 79), 1.2, 0.56),
      (Offset(172, 62), 1.2, 0.65),
      (Offset(179, 56), 0.7, 0.68),
      (Offset(172, -18), 1.2, 0.74),
      (Offset(176, -25), 0.7, 0.76),
      (Offset(121, -105), 1.1, 0.79),
      (Offset(112, -112), 0.7, 0.84),
      (Offset(170, -112), 0.9, 0.86),
    ]) {
      canvas.drawCircle(
        position,
        size * _phase(start, start + 0.13),
        Paint()..color = _honey,
      );
    }
    canvas.restore();
  }

  void _trace(Canvas canvas, Path path, double progress, {double width = 0.8}) {
    if (progress == 0) return;
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = _stem
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _leaf(
    Canvas canvas,
    Offset at,
    double angle,
    double length,
    double width,
    Color fill,
    double progress,
  ) {
    if (progress == 0) return;
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      ..scale(progress);
    final shape = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        length * 0.31,
        -width,
        length * 0.69,
        -width * 0.5,
        length,
        -width * 0.18,
      )
      ..cubicTo(length * 0.67, width * 0.67, length * 0.29, width * 0.5, 0, 0)
      ..close();
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..color = _vein
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.46,
    );
    canvas.drawPath(
      Path()
        ..moveTo(1, 0)
        ..quadraticBezierTo(
          length * 0.6,
          -width * 0.27,
          length * 0.93,
          -width * 0.17,
        ),
      Paint()
        ..color = _vein.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.45,
    );
    canvas.restore();
  }

  void _flower(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    Color fill,
    Color outline,
    int petals,
  ) {
    if (progress == 0) return;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(progress)
      ..rotate(-0.22);
    final fillPaint = Paint()..color = fill.withValues(alpha: 0.78);
    final edge = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.63;
    for (var i = 0; i < petals; i++) {
      final r = radius * (i.isEven ? 1 : 0.88);
      final petal = Path()
        ..moveTo(0, -r * 0.13)
        ..cubicTo(-r * 0.41, -r * 0.40, -r * 0.48, -r * 0.94, -r * 0.15, -r)
        ..cubicTo(r * 0.14, -r * 1.13, r * 0.46, -r * 0.78, r * 0.34, -r * 0.50)
        ..quadraticBezierTo(r * 0.25, -r * 0.31, 0, -r * 0.13)
        ..close();
      canvas.drawPath(petal, fillPaint);
      canvas.drawPath(petal, edge);
      canvas.drawPath(
        Path()
          ..moveTo(0, -r * 0.24)
          ..quadraticBezierTo(-r * 0.14, -r * 0.49, -r * 0.12, -r * 0.71),
        Paint()
          ..color = outline.withValues(alpha: 0.48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.49,
      );
      canvas.rotate(2 * math.pi / petals);
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.19,
      Paint()..color = const Color(0xFFF0D7A3),
    );
    for (var i = 0; i < petals; i++) {
      canvas.rotate(2 * math.pi / petals);
      canvas.drawCircle(
        Offset(0, -radius * 0.13),
        0.78,
        Paint()..color = _honey,
      );
    }
    canvas.drawCircle(Offset.zero, 0.85, Paint()..color = outline);
    canvas.restore();
  }

  void _bud(
    Canvas canvas,
    Offset at,
    double angle,
    double progress,
    Color tint,
  ) {
    if (progress == 0) return;
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      ..scale(progress);
    final shape = Path()
      ..moveTo(0, 3)
      ..cubicTo(-3, 0, -3, -5, 0, -6)
      ..cubicTo(3, -5, 3, 0, 0, 3)
      ..close();
    canvas.drawPath(shape, Paint()..color = tint.withValues(alpha: 0.54));
    canvas.drawPath(
      shape,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BotanicalPainter oldDelegate) =>
      growth != oldDelegate.growth;
}
