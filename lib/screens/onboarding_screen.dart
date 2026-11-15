import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../nutrition_calc.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Collects body details and builds the daily plan. Also used from the
/// profile screen (with [existing]) to redo the plan later.
class OnboardingScreen extends StatefulWidget {
  final AppUser user;
  final Profile? existing;
  const OnboardingScreen({super.key, required this.user, this.existing});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = 7;
  final _controller = PageController();
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.user.name.split(' ').first,
  );
  int _page = 0;
  bool _saving = false;
  late bool _share = widget.existing?.shareForResearch ?? false;

  late Sex _sex = widget.existing?.sex ?? Sex.male;
  late double _age = (widget.existing?.age ?? 28).toDouble();
  late double _height = widget.existing?.heightCm ?? 170;
  late double _weight = widget.existing?.weightKg ?? 70;
  late double _target = widget.existing?.targetWeightKg ?? 65;
  late ActivityLevel _activity =
      widget.existing?.activity ?? ActivityLevel.light;
  late Goal _goal = widget.existing?.goal ?? Goal.lose;
  late double _rate = widget.existing?.weeklyRateKg ?? 0.5;

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  Profile get _plan => buildPlan(
    name: _name.text.trim(),
    sex: _sex,
    birthYear: DateTime.now().year - _age.round(),
    heightCm: _height,
    weightKg: _weight,
    targetWeightKg: _goal == Goal.maintain ? _weight : _target,
    activity: _activity,
    goal: _goal,
    weeklyRateKg: _rate,
    stepTracking: widget.existing?.stepTracking ?? false,
  ).copyWith(shareForResearch: _share);

  String? get _blocker {
    if (_page == 0 && _name.text.trim().isEmpty) return 'Enter your name';
    if (_page == 5 && _goal == Goal.lose && _target >= _weight) {
      return 'Target must be below your current weight';
    }
    if (_page == 5 && _goal == Goal.gain && _target <= _weight) {
      return 'Target must be above your current weight';
    }
    return null;
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await Services.of(context).repo.saveProfile(widget.user.uid, _plan);
      if (mounted && widget.existing != null) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, 'Could not save your profile. $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blocker = _blocker;
    final last = _page == _pages - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: _page > 0
                            ? () => _go(_page - 1)
                            : widget.existing != null
                            ? () => Navigator.of(context).pop()
                            : null,
                        icon: Icon(
                          _page == 0 && widget.existing != null
                              ? Icons.close_rounded
                              : Icons.arrow_back_rounded,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: (_page + 1) / _pages),
                            duration: const Duration(milliseconds: 320),
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      _Step(
                        title: 'What should we call you?',
                        subtitle:
                            'ReemGym builds a plan around you. '
                            'It takes about a minute.',
                        child: TextField(
                          controller: _name,
                          autofocus: widget.existing == null,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (_blocker == null) _go(1);
                          },
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                          ),
                        ),
                      ),
                      _Step(
                        title: 'Which body type fits you?',
                        subtitle:
                            'Used only for the calorie formula, which '
                            'differs for male and female bodies.',
                        child: Column(
                          children: [
                            for (final s in Sex.values)
                              _Choice(
                                title: s == Sex.male ? 'Male' : 'Female',
                                icon: s == Sex.male
                                    ? Icons.male_rounded
                                    : Icons.female_rounded,
                                selected: _sex == s,
                                onTap: () => setState(() => _sex = s),
                              ),
                          ],
                        ),
                      ),
                      _Step(
                        title: 'How old are you?',
                        subtitle: 'Energy needs change with age.',
                        child: NumberStepper(
                          value: _age,
                          min: 14,
                          max: 90,
                          unit: 'years',
                          onChanged: (v) => setState(() => _age = v),
                        ),
                      ),
                      _Step(
                        title: 'Your height and weight',
                        subtitle:
                            'A rough number is fine. You can update '
                            'your weight any time.',
                        child: Column(
                          children: [
                            NumberStepper(
                              value: _height,
                              min: 120,
                              max: 220,
                              unit: 'cm',
                              onChanged: (v) => setState(() => _height = v),
                            ),
                            const SizedBox(height: 20),
                            NumberStepper(
                              value: _weight,
                              min: 30,
                              max: 200,
                              step: 0.5,
                              unit: 'kg',
                              onChanged: (v) => setState(() => _weight = v),
                            ),
                          ],
                        ),
                      ),
                      _Step(
                        title: 'How active is a normal week?',
                        subtitle: 'Not counting workouts you will log here.',
                        child: Column(
                          children: [
                            for (final a in ActivityLevel.values)
                              _Choice(
                                title: a.label,
                                subtitle: a.hint,
                                selected: _activity == a,
                                onTap: () => setState(() => _activity = a),
                              ),
                          ],
                        ),
                      ),
                      _Step(
                        title: 'What is your goal?',
                        subtitle: 'This sets your daily calorie budget.',
                        child: Column(
                          children: [
                            SegmentedButton<Goal>(
                              segments: [
                                for (final g in Goal.values)
                                  ButtonSegment(
                                    value: g,
                                    label: Text(
                                      const [
                                        'Lose',
                                        'Maintain',
                                        'Gain',
                                      ][g.index],
                                    ),
                                  ),
                              ],
                              selected: {_goal},
                              onSelectionChanged: (s) => setState(() {
                                _goal = s.first;
                                if (_goal == Goal.lose && _target >= _weight) {
                                  _target = _weight - 5;
                                } else if (_goal == Goal.gain &&
                                    _target <= _weight) {
                                  _target = _weight + 5;
                                }
                              }),
                            ),
                            if (_goal != Goal.maintain) ...[
                              const SizedBox(height: 28),
                              Text(
                                'Target weight',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              NumberStepper(
                                value: _target,
                                min: 30,
                                max: 200,
                                step: 0.5,
                                unit: 'kg',
                                onChanged: (v) => setState(() => _target = v),
                              ),
                              const SizedBox(height: 16),
                              Text('Pace', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 12),
                              SegmentedButton<double>(
                                segments: const [
                                  ButtonSegment(
                                    value: 0.25,
                                    label: Text('Gentle'),
                                  ),
                                  ButtonSegment(
                                    value: 0.5,
                                    label: Text('Steady'),
                                  ),
                                  ButtonSegment(
                                    value: 0.75,
                                    label: Text('Fast'),
                                  ),
                                ],
                                selected: {_rate},
                                onSelectionChanged: (s) =>
                                    setState(() => _rate = s.first),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$_rate kg per week, about '
                                '${((_target - _weight).abs() / _rate).ceil()} '
                                'weeks to reach your target',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _Step(
                        title: _name.text.trim().isEmpty
                            ? 'Your plan is ready'
                            : '${_name.text.trim().split(' ').first}, '
                                  'your plan is ready',
                        subtitle:
                            'Estimated from your details. You can '
                            'fine-tune every number later in Profile.',
                        child: Column(
                          children: [
                            _PlanSummary(plan: _plan),
                            const SizedBox(height: 14),
                            Panel(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                title: const Text('Share meals for research'),
                                subtitle: const Text(
                                  'Optional. Saves your meal photos, the AI '
                                  'estimates and your corrections to help '
                                  'improve food recognition. You can change '
                                  'this in Profile.',
                                ),
                                value: _share,
                                onChanged: (v) => setState(() => _share = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      if (blocker != null && _page != 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            blocker,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      FilledButton(
                        onPressed: blocker != null || _saving
                            ? null
                            : last
                            ? _finish
                            : () => _go(_page + 1),
                        child: Text(
                          last
                              ? (widget.existing == null
                                    ? 'Start tracking'
                                    : 'Save new plan')
                              : 'Continue',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Step({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 28),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? scheme.primary : scheme.outlineVariant,
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

class _PlanSummary extends StatelessWidget {
  final Profile plan;
  const _PlanSummary({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget macro(String label, int grams, Color color) => Expanded(
      child: Panel(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text('$grams g', style: theme.textTheme.titleLarge),
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
    Widget row(IconData icon, Color color, String label, String value) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        );
    return Column(
      children: [
        Ring(
          progress: 1,
          color: scheme.primary,
          size: 180,
          stroke: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatNumber(plan.calorieTarget),
                style: theme.textTheme.displaySmall,
              ),
              Text(
                'kcal per day',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            macro('Protein', plan.proteinTarget, AppColors.protein),
            const SizedBox(width: 10),
            macro('Carbs', plan.carbsTarget, AppColors.carbs),
            const SizedBox(width: 10),
            macro('Fat', plan.fatTarget, AppColors.fat),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              row(
                Icons.water_drop_rounded,
                AppColors.water,
                'Water',
                '${(plan.waterGoalMl / 1000).toStringAsFixed(1)} L',
              ),
              const Divider(),
              row(
                Icons.directions_walk_rounded,
                AppColors.steps,
                'Steps',
                formatNumber(plan.stepGoal),
              ),
              const Divider(),
              row(
                Icons.monitor_weight_outlined,
                scheme.primary,
                'BMI today',
                bmi(plan.weightKg, plan.heightCm).toStringAsFixed(1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
