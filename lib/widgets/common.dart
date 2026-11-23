import 'dart:math';

import 'package:flutter/material.dart';

/// Circular progress ring with rounded ends and a centred child.
class Ring extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  const Ring({
    super.key,
    required this.progress,
    required this.color,
    this.size = 120,
    this.stroke = 12,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.isFinite ? progress : 0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value,
            color,
            Theme.of(context).colorScheme.surfaceContainerHighest,
            stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter(this.progress, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, paint..color = track);
    final sweep = progress.clamp(0.0, 1.0) * 2 * pi;
    if (sweep > 0) {
      canvas.drawArc(rect, -pi / 2, sweep, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Labelled horizontal progress bar used for macros.
class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final int target;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: target <= 0 ? 0 : (value / target).clamp(0, 1)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${value.round()}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: ' / $target g',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Rounded surface used for every dashboard block.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small coloured dot + "12 g" style label.
class MacroChip extends StatelessWidget {
  final String label;
  final double grams;
  final Color color;
  const MacroChip(this.label, this.grams, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ${grams.round()} g',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Big number with − / + buttons and a slider; used for body measurements.
class NumberStepper extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;

  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.unit = '',
  });

  void _set(double v) {
    final snapped = (v / step).round() * step;
    onChanged(snapped.clamp(min, max).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = step < 1
        ? value.toStringAsFixed(1)
        : value.round().toString();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: value > min ? () => _set(value - step) : null,
              icon: const Icon(Icons.remove),
              tooltip: 'Decrease',
            ),
            SizedBox(
              width: 190,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label, style: theme.textTheme.displaySmall),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton.filledTonal(
              onPressed: value < max ? () => _set(value + step) : null,
              icon: const Icon(Icons.add),
              tooltip: 'Increase',
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: _set,
        ),
      ],
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String formatNumber(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Water volume for display: "250 ml" under a litre, "1.5 L" from a litre up.
String formatWater(num ml) {
  if (ml < 1000) return '${ml.round()} ml';
  var text = (ml / 1000).toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return '$text L';
}

/// Height of the floating bottom nav pill and Log button in the home shell.
const double kFloatingNavHeight = 68;

/// Gap between the floating nav and the bottom safe area.
const double kFloatingNavMargin = 12;

/// Bottom padding for a scrolling tab body so its last item can scroll fully
/// clear of the floating nav (nav height, its margin, the device's bottom
/// inset such as the gesture bar, plus some breathing room).
///
/// Inside the home shell's `Scaffold(extendBody: true)` the body's
/// `MediaQuery` bottom padding already includes the nav; the explicit sum is
/// a fallback so the result is never smaller than the nav's footprint.
double floatingNavClearance(BuildContext context, {double gap = 24}) {
  final covered = max(
    MediaQuery.paddingOf(context).bottom,
    MediaQuery.viewPaddingOf(context).bottom +
        kFloatingNavHeight +
        kFloatingNavMargin,
  );
  return covered + gap;
}
