import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Native vector mark, independent of generated mockups or image assets.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.color = AppTheme.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PulsePainter(color)),
    ),
  );
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final heart = Path()
      ..moveTo(20, 35)
      ..cubicTo(15, 31, 3, 23, 3, 13)
      ..cubicTo(3, 3, 15, 2, 20, 10)
      ..cubicTo(25, 2, 37, 3, 37, 13)
      ..cubicTo(37, 23, 25, 31, 20, 35);
    canvas.drawPath(
      heart,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final pulse = Path()
      ..moveTo(2, 20)
      ..lineTo(12, 20)
      ..lineTo(16, 14)
      ..lineTo(21, 26)
      ..lineTo(25, 19)
      ..lineTo(38, 19);
    canvas.drawPath(
      pulse,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => color != oldDelegate.color;
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.light = false, this.large = false});
  final bool light;
  final bool large;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(
        size: large ? 52 : 30,
        color: light ? Colors.white : AppTheme.primary,
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          'NursePulse',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: light ? Colors.white : AppTheme.textHeading,
            fontSize: large ? 28 : 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
