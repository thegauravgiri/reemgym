import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// Number that counts up or down to its new value.
class CountUp extends StatelessWidget {
  final double value;
  final TextStyle? style;
  const CountUp(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value),
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text(formatNumber(v), style: style),
  );
}

/// 270° gauge with a gradient stroke and a soft glow under the filled part.
class ArcGauge extends StatelessWidget {
  final double progress;
  final List<Color> colors;
  final double size;
  final double stroke;
  final Widget child;

  const ArcGauge({
    super.key,
    required this.progress,
    required this.colors,
    required this.child,
    this.size = 230,
    this.stroke = 18,
  });

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.isFinite ? progress.clamp(0.0, 1.0) : 0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size * 0.86,
        child: CustomPaint(
          painter: _ArcPainter(v, colors, track, stroke),
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.1),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  static const _start = 135 * pi / 180;
  static const _sweep = 270 * pi / 180;
  final double progress;
  final List<Color> colors;
  final Color track;
  final double stroke;
  _ArcPainter(this.progress, this.colors, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    final rect = Rect.fromLTWH(0, 0, side, side).deflate(stroke / 2 + 6);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, base..color = track);
    if (progress <= 0) return;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: _sweep,
      colors: colors,
      transform: const GradientRotation(_start - 0.12),
    ).createShader(rect);
    final sweep = _sweep * progress;
    canvas.drawArc(
      rect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..color = colors.last.withValues(alpha: 0.55),
    );
    canvas.drawArc(rect, _start, sweep, false, base..shader = shader);
    // Bright dot at the tip of the arc.
    final angle = _start + sweep;
    final tip = rect.center + Offset(cos(angle), sin(angle)) * rect.width / 2;
    canvas.drawCircle(tip, stroke * 0.22, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.track != track || old.colors != colors;
}

/// Soft blurred colour blobs behind a screen's content.
class GlowBackground extends StatelessWidget {
  final Widget child;
  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget blob(Color color, double size, Alignment at) => Align(
      alignment: at,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: dark ? 0.32 : 0.38),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
          child: Stack(
            fit: StackFit.expand,
            children: [
              blob(AppColors.lime, 320, const Alignment(-1.4, -1.0)),
              blob(AppColors.mint, 260, const Alignment(1.5, -0.5)),
              blob(AppColors.steps, 240, const Alignment(1.2, 1.1)),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// A glass that fills with water; the surface ripples briefly when the level
/// changes.
class WaterGlass extends StatefulWidget {
  final double level;
  final double width;
  final double height;
  final Widget? child;
  const WaterGlass({
    super.key,
    required this.level,
    this.width = 84,
    this.height = 104,
    this.child,
  });

  @override
  State<WaterGlass> createState() => _WaterGlassState();
}

class _WaterGlassState extends State<WaterGlass>
    with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late double _from = widget.level;

  @override
  void didUpdateWidget(WaterGlass old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) {
      _from = old.level;
      _wave.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _wave,
      builder: (context, child) {
        final t = _wave.isAnimating || _wave.value > 0 ? _wave.value : 1.0;
        final eased = Curves.easeOutCubic.transform(t);
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: _WaterPainter(
              level: lerpDouble(_from, widget.level, eased)!.clamp(0.0, 1.0),
              phase: t * 4 * pi,
              ripple: (1 - t) * 5,
              track: track,
            ),
            child: Center(child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _WaterPainter extends CustomPainter {
  final double level;
  final double phase;
  final double ripple;
  final Color track;
  _WaterPainter({
    required this.level,
    required this.phase,
    required this.ripple,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Slightly tapered glass.
    final glass = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.86, size.height - 14)
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height,
        size.width * 0.7,
        size.height,
      )
      ..lineTo(size.width * 0.3, size.height)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height,
        size.width * 0.14,
        size.height - 14,
      )
      ..close();
    canvas.drawPath(glass, Paint()..color = track);
    if (level > 0) {
      canvas.save();
      canvas.clipPath(glass);
      final top = size.height * (1 - level);
      final water = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 2) {
        water.lineTo(x, top + sin(x / size.width * 2 * pi + phase) * ripple);
      }
      water
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        water,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7DD8FF), AppColors.water, Color(0xFF1C8FD6)],
          ).createShader(Offset.zero & size),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WaterPainter old) =>
      old.level != level || old.phase != phase || old.track != track;
}

/// One week of day buttons; days after today are disabled.
class WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  const WeekStrip({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(selected.year, selected.month, selected.day);
    final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final d = DateTime(monday.year, monday.month, monday.day + i);
                final isSelected = d == day;
                final future = d.isAfter(today);
                final fg = isSelected
                    ? scheme.onPrimary
                    : future
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                    : scheme.onSurface;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: dayKeyOf(d),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: future ? null : () => onSelect(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.brand : null,
                          color: isSelected ? null : scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              letters[i],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? const Color(0xFF10160A)
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: future ? 0.4 : 1,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${d.day}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isSelected
                                    ? const Color(0xFF10160A)
                                    : fg,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d == today && !isSelected
                                    ? scheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The four-colour Google "G".
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.2;
    final rect = (Offset.zero & size).deflate(w / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    void arc(double from, double sweep, Color color) => canvas.drawArc(
      rect,
      from * pi / 180,
      sweep * pi / 180,
      false,
      paint..color = color,
    );
    arc(-45, -90, const Color(0xFFEA4335)); // red, top
    arc(-135, -90, const Color(0xFFFBBC05)); // yellow, left
    arc(135, -90, const Color(0xFF34A853)); // green, bottom
    arc(45, -57, const Color(0xFF4285F4)); // blue, right
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, size.height / 2 - w / 2, size.width / 2, w),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}

/// Photo frame with corner brackets and a sweeping scan line.
class ScanFrame extends StatefulWidget {
  final Widget child;
  final bool scanning;
  const ScanFrame({super.key, required this.child, this.scanning = true});

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.scanning) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ScanFrame old) {
    super.didUpdateWidget(old);
    if (widget.scanning && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.scanning) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _ScanPainter(
                widget.scanning
                    ? Curves.easeInOut.transform(_controller.value)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final double? position;
  _ScanPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 22.0, arm = 34.0;
    final bracket = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(1, 1), (-1, 1), (1, -1), (-1, -1)]) {
      final corner = Offset(
        dx == 1 ? inset : size.width - inset,
        dy == 1 ? inset : size.height - inset,
      );
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + arm * dx, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + arm * dy),
        bracket,
      );
    }
    final p = position;
    if (p == null) return;
    final y = inset + (size.height - inset * 2) * p;
    final band = Rect.fromLTWH(0, y - 60, size.width, 60);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.lime.withValues(alpha: 0),
            AppColors.lime.withValues(alpha: 0.28),
          ],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(inset, y),
      Offset(size.width - inset, y),
      Paint()
        ..color = AppColors.lime
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.position != position;
}
