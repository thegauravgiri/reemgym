import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class ProgressScreen extends StatefulWidget {
  final String uid;
  final Profile profile;
  const ProgressScreen({super.key, required this.uid, required this.profile});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const _loadDays = 90;
  Future<List<DaySummary>>? _history;
  int _range = 7;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _history ??= _load();
  }

  Future<List<DaySummary>> _load() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - (_loadDays - 1));
    return Services.of(context).repo.history(widget.uid, dayKeyOf(from));
  }

  Future<void> _logWeight() async {
    await showWeightSheet(
      context,
      widget.uid,
      widget.profile,
      dayKeyOf(DateTime.now()),
    );
    if (mounted) setState(() => _history = _load());
  }

  /// Days in a row with at least one meal logged. Today does not break the
  /// streak until it is over.
  int _streak(List<DaySummary> all) {
    var count = 0;
    for (var i = all.length - 1; i >= 0; i--) {
      if (all[i].foodCount > 0) {
        count++;
      } else if (i != all.length - 1) {
        break;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FutureBuilder<List<DaySummary>>(
      future: _history,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load your history. ${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? const <DaySummary>[];
        final days = all.length > _range
            ? all.sublist(all.length - _range)
            : all;
        final logged = days.where((d) => d.foodCount > 0).toList();
        double avg(Iterable<num> values) =>
            values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
        final weights = all.where((d) => d.weightKg != null).toList();
        final rangeWeights = days.where((d) => d.weightKg != null).toList();
        final change = rangeWeights.length < 2
            ? null
            : rangeWeights.last.weightKg! - rangeWeights.first.weightKg!;

        Widget tile(String label, String value, IconData icon, Color color) =>
            Expanded(
              child: Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 10),
                    Text(value, style: theme.textTheme.titleLarge),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            floatingNavClearance(context),
          ),
          children: [
            Text('Progress', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 14),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                tile(
                  'Day streak',
                  '${_streak(all)}',
                  Icons.local_fire_department_rounded,
                  AppColors.burn,
                ),
                const SizedBox(width: 10),
                tile(
                  'Avg kcal eaten',
                  logged.isEmpty
                      ? '–'
                      : formatNumber(avg(logged.map((d) => d.eaten))),
                  Icons.restaurant_rounded,
                  scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                tile(
                  'Avg steps',
                  formatNumber(
                    avg(days.where((d) => d.steps > 0).map((d) => d.steps)),
                  ),
                  Icons.directions_walk_rounded,
                  AppColors.steps,
                ),
                const SizedBox(width: 10),
                tile(
                  'Avg protein',
                  logged.isEmpty
                      ? '–'
                      : '${avg(logged.map((d) => d.protein)).round()} g',
                  Icons.egg_alt_rounded,
                  AppColors.protein,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calories eaten', style: theme.textTheme.titleMedium),
                  Text(
                    'Dashed line is your ${formatNumber(widget.profile.calorieTarget)} kcal target',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 180,
                    child: logged.isEmpty
                        ? _empty(context, 'Log a meal to see your trend')
                        : _CalorieChart(
                            days: days,
                            target: widget.profile.calorieTarget,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Weight', style: theme.textTheme.titleMedium),
                            Text(
                              change == null
                                  ? 'Now ${widget.profile.weightKg.toStringAsFixed(1)} kg · '
                                        'target ${widget.profile.targetWeightKg.toStringAsFixed(1)} kg'
                                  : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg '
                                        'in this period · target '
                                        '${widget.profile.targetWeightKg.toStringAsFixed(1)} kg',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _logWeight,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Log'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 180,
                    child: weights.length < 2
                        ? _empty(
                            context,
                            'Log your weight on two days to see a trend',
                          )
                        : _WeightChart(days: weights),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context, String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

String _shortDate(String dayKey) =>
    DateFormat('d MMM').format(dayFromKey(dayKey));

class _CalorieChart extends StatelessWidget {
  final List<DaySummary> days;
  final int target;
  const _CalorieChart({required this.days, required this.target});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);
    final peak = days.fold<double>(
      target.toDouble(),
      (m, d) => d.eaten > m ? d.eaten : m,
    );
    final every = (days.length / 6).ceil();
    return BarChart(
      BarChartData(
        maxY: peak * 1.15,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.surfaceContainerHighest,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${_shortDate(days[group.x].dayKey)}\n${rod.toY.round()} kcal',
              TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: target.toDouble(),
              color: scheme.onSurfaceVariant,
              strokeWidth: 1.2,
              dashArray: [6, 5],
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length || i % every != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    days.length <= 7
                        ? DateFormat('E').format(dayFromKey(days[i].dayKey))
                        : _shortDate(days[i].dayKey),
                    style: label,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].eaten,
                  width: days.length <= 7
                      ? 18
                      : days.length <= 30
                      ? 6
                      : 2.5,
                  borderRadius: BorderRadius.circular(6),
                  color: days[i].eaten > target * 1.05
                      ? AppColors.burn
                      : scheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  /// Only days that have a weigh-in, oldest first.
  final List<DaySummary> days;
  const _WeightChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);
    final first = dayFromKey(days.first.dayKey);
    double x(DaySummary d) =>
        dayFromKey(d.dayKey).difference(first).inHours / 24;
    final values = days.map((d) => d.weightKg!).toList();
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: lo - 1,
        maxY: hi + 1,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.surfaceContainerHighest,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat('d MMM').format(first.add(Duration(days: s.x.round())))}\n'
                  '${s.y.toStringAsFixed(1)} kg',
                  TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) =>
                  value == meta.min || value == meta.max
                  ? const SizedBox.shrink()
                  : Text(value.toStringAsFixed(0), style: label),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final d in days) FlSpot(x(d), d.weightKg!)],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.water,
            barWidth: 3,
            dotData: FlDotData(show: days.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.water.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
