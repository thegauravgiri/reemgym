import 'package:flutter/material.dart';

/// The ReemGym mark: an R with a loaded barbell running through its middle.
///
/// Drawn on the same 200×200 grid as the launcher icon artwork
/// (assets/brand/icon.svg), so the two always match.
class ReemMark extends StatelessWidget {
  const ReemMark({super.key, this.size = 40, this.color});

  final double size;

  /// Defaults to the current icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    return Semantics(
      label: 'ReemGym',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ReemMarkPainter(c)),
      ),
    );
  }
}

class _ReemMarkPainter extends CustomPainter {
  _ReemMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Artwork bounds are x 12–188, y 28–176; centre it in the box.
    final s = size.shortestSide / 200;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-100, -102);

    // The R: stem, bowl and leg.
    final r = Path()
      ..moveTo(76, 164)
      ..lineTo(76, 40)
      ..lineTo(110, 40)
      ..arcToPoint(const Offset(110, 104), radius: const Radius.circular(32))
      ..lineTo(76, 104)
      ..moveTo(106, 104)
      ..lineTo(146, 164);
    canvas.drawPath(
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The barbell across the bowl's closing stroke, a big and a small
    // plate on each end.
    final fill = Paint()..color = color;
    void bar(double x, double y, double w, double h, double rad) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(rad),
        ),
        fill,
      );
    }

    bar(35, 100, 130, 8, 4);
    bar(12, 78, 14, 52, 5);
    bar(28, 86, 7, 36, 3.5);
    bar(174, 78, 14, 52, 5);
    bar(165, 86, 7, 36, 3.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReemMarkPainter old) => old.color != color;
}
