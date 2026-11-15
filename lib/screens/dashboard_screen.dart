import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../models.dart';
import '../nutrition_calc.dart';
import '../services/auth_service.dart';
import '../services/step_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import 'exercise_screen.dart';
import 'food_screens.dart';
import 'home_shell.dart';

class DashboardScreen extends StatefulWidget {
  final AppUser user;
  final Profile profile;
  final DateTime day;
  final ValueChanged<DateTime> onDayChanged;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.profile,
    required this.day,
    required this.onDayChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Stream<List<FoodEntry>>? _food;
  Stream<List<ExerciseEntry>>? _exercise;
  Stream<DayStats>? _stats;
  String _boundKey = '';

  /// Entries swiped away, hidden at once so the list never shows a dismissed
  /// row while the delete is still on its way through the data stream.
  final _hidden = <String>{};

  String get _dayKey => dayKeyOf(widget.day);
  bool get _isToday => _dayKey == dayKeyOf(DateTime.now());
  String get _uid => widget.user.uid;

  void _bind() {
    if (_boundKey == _dayKey) return;
    _boundKey = _dayKey;
    final repo = Services.of(context).repo;
    _food = repo.watchFood(_uid, _dayKey);
    _exercise = repo.watchExercise(_uid, _dayKey);
    _stats = repo.watchDay(_uid, _dayKey);
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) widget.onDayChanged(picked);
  }

  String get _dayLabel {
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(widget.day.year, widget.day.month, widget.day.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(widget.day);
  }

  Future<void> _enableSteps(int savedSteps) async {
    final services = Services.of(context);
    final ok = await services.steps.enable(savedSteps: savedSteps);
    if (!mounted) return;
    if (ok) {
      await services.repo.saveProfile(
        _uid,
        widget.profile.copyWith(stepTracking: true),
      );
    } else {
      showMessage(
        context,
        'Step counting needs motion or health access. '
        'Allow it in your phone settings and try again.',
      );
    }
  }

  void _deleteFood(FoodEntry entry) {
    final repo = Services.of(context).repo;
    setState(() => _hidden.add(entry.id));
    repo.deleteFood(_uid, entry.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${entry.title}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (mounted) setState(() => _hidden.remove(entry.id));
              repo.saveFood(_uid, entry);
            },
          ),
        ),
      );
  }

  void _deleteExercise(ExerciseEntry entry) {
    final repo = Services.of(context).repo;
    setState(() => _hidden.add(entry.id));
    repo.deleteExercise(_uid, entry.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${entry.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (mounted) setState(() => _hidden.remove(entry.id));
              repo.saveExercise(_uid, entry);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    _bind();
    final steps = Services.of(context).steps;
    return StreamBuilder<List<FoodEntry>>(
      stream: _food,
      builder: (context, food) => StreamBuilder<List<ExerciseEntry>>(
        stream: _exercise,
        builder: (context, exercise) => StreamBuilder<DayStats>(
          stream: _stats,
          builder: (context, stats) => ValueListenableBuilder<int>(
            valueListenable: steps.steps,
            builder: (context, liveSteps, _) {
              final error = food.error ?? exercise.error ?? stats.error;
              final day = stats.data ?? DayStats(dayKey: _dayKey);
              final live = _isToday && steps.isRunning;
              return _content(
                context,
                [
                  for (final e in food.data ?? const <FoodEntry>[])
                    if (!_hidden.contains(e.id)) e,
                ],
                [
                  for (final e in exercise.data ?? const <ExerciseEntry>[])
                    if (!_hidden.contains(e.id)) e,
                ],
                day,
                live && liveSteps > day.steps ? liveSteps : day.steps,
                live,
                error,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<FoodEntry> food,
    List<ExerciseEntry> exercise,
    DayStats day,
    int stepCount,
    bool live,
    Object? error,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.profile;
    final services = Services.of(context);

    double sum(double Function(FoodEntry) f) =>
        food.fold(0, (total, e) => total + f(e));
    final eaten = sum((e) => e.calories);
    final exerciseKcal = exercise.fold(0.0, (total, e) => total + e.calories);
    final stepKcal = stepCalories(stepCount, p.weightKg);
    final burned = exerciseKcal + stepKcal;
    final budget = p.calorieTarget + burned;
    final remaining = budget - eaten;
    final over = remaining < 0;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final first = p.name.split(' ').first;

    Widget stat(String label, double value, IconData icon, Color color) =>
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountUp(value, style: theme.textTheme.titleMedium),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

    final sections = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $first',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(_dayLabel, style: theme.textTheme.headlineMedium),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Pick a date',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      const SizedBox(height: 16),
      WeekStrip(selected: widget.day, onSelect: widget.onDayChanged),
      if (services.preview) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Preview mode: data is not saved and food analysis returns '
            'a sample.',
            style: TextStyle(color: scheme.onTertiaryContainer),
          ),
        ),
      ],
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          'Could not load this day. $error',
          style: TextStyle(color: scheme.error),
        ),
      ],
      const SizedBox(height: 16),
      Panel(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
        child: Column(
          children: [
            ArcGauge(
              progress: budget <= 0 ? 0 : eaten / budget,
              colors: over
                  ? [AppColors.burn, scheme.error]
                  : const [AppColors.lime, AppColors.mint],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountUp(
                    remaining.abs(),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: over ? scheme.error : null,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    over ? 'kcal over' : 'kcal left',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Goal ${formatNumber(p.calorieTarget)}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                stat('Eaten', eaten, Icons.restaurant_rounded, scheme.primary),
                Container(width: 1, height: 34, color: scheme.outlineVariant),
                stat(
                  'Burned',
                  burned,
                  Icons.local_fire_department_rounded,
                  AppColors.burn,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MacroTile(
              'Protein',
              sum((e) => e.protein),
              p.proteinTarget,
              AppColors.protein,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MacroTile(
              'Carbs',
              sum((e) => e.carbs),
              p.carbsTarget,
              AppColors.carbs,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MacroTile(
              'Fat',
              sum((e) => e.fat),
              p.fatTarget,
              AppColors.fat,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StepsCard(
                steps: stepCount,
                goal: p.stepGoal,
                kcal: stepKcal,
                live: live,
                canEnable:
                    _isToday &&
                    services.steps.supported &&
                    !services.steps.isRunning,
                supported: services.steps.supported,
                movement: services.steps.movement,
                onEnable: () => _enableSteps(day.steps),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WaterCard(
                ml: day.waterMl,
                goal: p.waterGoalMl,
                onChange: (delta) => services.repo.updateDay(
                  _uid,
                  _dayKey,
                  waterMl: (day.waterMl + delta).clamp(0, 20000),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text('Meals', style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      for (final meal in MealType.values) ...[
        _MealSection(
          meal: meal,
          entries: food.where((e) => e.meal == meal).toList(),
          onAdd: () => showAddSheet(
            context,
            p,
            LogTarget(_uid, _dayKey, meal: meal, research: p.shareForResearch),
          ),
          onOpen: (e) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  FoodReviewScreen(uid: _uid, entry: e, isNew: false),
            ),
          ),
          onDelete: _deleteFood,
        ),
        const SizedBox(height: 12),
      ],
      _Section(
        title: 'Exercise',
        icon: Icons.fitness_center_rounded,
        color: AppColors.burn,
        trailing: '${exerciseKcal.round()} kcal',
        addTooltip: 'Log exercise',
        onAdd: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExerciseScreen(
              uid: _uid,
              dayKey: _dayKey,
              weightKg: p.weightKg,
            ),
          ),
        ),
        emptyText: 'No workouts logged',
        children: [
          for (final e in exercise)
            _Swipe(
              id: e.id,
              onDelete: () => _deleteExercise(e),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                title: Text(e.name),
                subtitle: Text('${e.minutes} min'),
                trailing: Text(
                  '−${e.calories.round()} kcal',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.burn,
                  ),
                ),
              ),
            ),
        ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
      itemCount: sections.length,
      itemBuilder: (context, i) => i < 8
          ? sections[i]
                .animate(key: ValueKey('s$i'))
                .fadeIn(delay: (60 * i).ms, duration: 380.ms)
                .slideY(begin: 0.06, curve: Curves.easeOutCubic)
          : sections[i],
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final double value;
  final int target;
  final Color color;
  const _MacroTile(this.label, this.value, this.target, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Ring(
            progress: target <= 0 ? 0 : value / target,
            color: color,
            size: 62,
            stroke: 7,
            child: Text('${value.round()}', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.titleSmall),
          Text(
            'of $target g',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  final int steps;
  final int goal;
  final double kcal;
  final bool live;
  final bool canEnable;
  final bool supported;
  final ValueNotifier<Movement> movement;
  final VoidCallback onEnable;

  const _StepsCard({
    required this.steps,
    required this.goal,
    required this.kcal,
    required this.live,
    required this.canEnable,
    required this.supported,
    required this.movement,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_walk_rounded,
                color: AppColors.steps,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text('Steps', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (live)
                ValueListenableBuilder<Movement>(
                  valueListenable: movement,
                  builder: (context, m, _) =>
                      m == Movement.walking || m == Movement.running
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.steps.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            m == Movement.running ? 'Running' : 'Walking',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.steps,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Ring(
              progress: goal <= 0 ? 0 : steps / goal,
              color: AppColors.steps,
              size: 104,
              stroke: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountUp(steps.toDouble(), style: theme.textTheme.titleLarge),
                  Text(
                    'steps',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (canEnable)
            Center(
              child: TextButton(
                onPressed: onEnable,
                child: const Text('Turn on'),
              ),
            )
          else
            Center(
              child: Text(
                !supported && steps == 0
                    ? 'Counted on your phone'
                    : 'of ${formatNumber(goal)} · ${kcal.round()} kcal',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  final int ml;
  final int goal;
  final ValueChanged<int> onChange;
  const _WaterCard({
    required this.ml,
    required this.goal,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_rounded,
                color: AppColors.water,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text('Water', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${(ml / 1000).toStringAsFixed(2)} L',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(child: WaterGlass(level: goal <= 0 ? 0 : ml / goal)),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: 'Remove a glass (250 ml)',
                visualDensity: VisualDensity.compact,
                onPressed: ml > 0 ? () => onChange(-250) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Expanded(
                child: Text(
                  'of ${(goal / 1000).toStringAsFixed(1)} L',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add a glass (250 ml)',
                visualDensity: VisualDensity.compact,
                onPressed: () => onChange(250),
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.water,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final MealType meal;
  final List<FoodEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<FoodEntry> onOpen;
  final ValueChanged<FoodEntry> onDelete;

  const _MealSection({
    required this.meal,
    required this.entries,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = entries.fold(0.0, (sum, e) => sum + e.calories);
    final (icon, color) = switch (meal) {
      MealType.breakfast => (Icons.free_breakfast_rounded, AppColors.carbs),
      MealType.lunch => (Icons.lunch_dining_rounded, AppColors.mint),
      MealType.dinner => (Icons.dinner_dining_rounded, AppColors.protein),
      MealType.snack => (Icons.cookie_rounded, AppColors.fat),
    };
    return _Section(
      title: meal.label,
      icon: icon,
      color: color,
      trailing: '${total.round()} kcal',
      addTooltip: 'Add to ${meal.label.toLowerCase()}',
      onAdd: onAdd,
      emptyText: 'Nothing logged yet',
      children: [
        for (final e in entries)
          _Swipe(
            id: e.id,
            onDelete: () => onDelete(e),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              onTap: () => onOpen(e),
              leading: Icon(switch (e.source) {
                'photo' => Icons.photo_camera_outlined,
                'text' => Icons.auto_awesome_outlined,
                _ => Icons.edit_note_rounded,
              }, color: theme.colorScheme.onSurfaceVariant),
              title: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'P ${e.protein.round()} g · '
                'C ${e.carbs.round()} g · F ${e.fat.round()} g',
              ),
              trailing: Text(
                '${e.calories.round()} kcal',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String trailing;
  final String addTooltip;
  final String emptyText;
  final VoidCallback onAdd;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.trailing,
    required this.addTooltip,
    required this.emptyText,
    required this.onAdd,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Panel(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(
                        children.isEmpty ? emptyText : trailing,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: addTooltip,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Swipe left to delete.
class _Swipe extends StatelessWidget {
  final String id;
  final VoidCallback onDelete;
  final Widget child;
  const _Swipe({required this.id, required this.onDelete, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: child,
    );
  }
}
