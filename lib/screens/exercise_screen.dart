import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models.dart';
import '../nutrition_calc.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pick an activity, set how long it lasted, and log the calories burned.
class ExerciseScreen extends StatefulWidget {
  final String uid;
  final String dayKey;
  final double weightKg;
  const ExerciseScreen({
    super.key,
    required this.uid,
    required this.dayKey,
    required this.weightKg,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  String _query = '';

  Future<void> _log(String name, int minutes, double calories) async {
    final repo = Services.of(context).repo;
    final navigator = Navigator.of(context);
    try {
      await repo.saveExercise(
        widget.uid,
        ExerciseEntry(
          id: newId(),
          dayKey: widget.dayKey,
          name: name,
          minutes: minutes,
          calories: calories,
          createdAt: DateTime.now(),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save. $e');
    }
  }

  Future<void> _pick(Activity activity) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (_) =>
          _DurationSheet(activity: activity, weightKg: widget.weightKg),
    );
    if (minutes == null) return;
    await _log(
      activity.name,
      minutes,
      exerciseCalories(
        met: activity.met,
        weightKg: widget.weightKg,
        minutes: minutes,
      ),
    );
  }

  Future<void> _custom() async {
    final result = await showModalBottomSheet<(String, int, double)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomSheet(initialName: _query),
    );
    if (result == null) return;
    await _log(result.$1, result.$2, result.$3);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final matches = activities
        .where((a) => a.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Log exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Search activities',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                for (final a in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      onTap: () => _pick(a),
                      child: Row(
                        children: [
                          Text(a.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              a.name,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${exerciseCalories(met: a.met, weightKg: widget.weightKg, minutes: 30).round()} kcal / 30 min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _custom,
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(
                    matches.isEmpty && _query.isNotEmpty
                        ? 'Add “$_query” as a custom activity'
                        : 'Custom activity',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationSheet extends StatefulWidget {
  final Activity activity;
  final double weightKg;
  const _DurationSheet({required this.activity, required this.weightKg});

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  double _minutes = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = exerciseCalories(
      met: widget.activity.met,
      weightKg: widget.weightKg,
      minutes: _minutes.round(),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.activity.emoji}  ${widget.activity.name}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            NumberStepper(
              value: _minutes,
              min: 5,
              max: 240,
              step: 5,
              unit: 'min',
              onChanged: (v) => setState(() => _minutes = v),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.burn,
                ),
                const SizedBox(width: 6),
                Text(
                  'About ${kcal.round()} kcal burned',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, _minutes.round()),
              child: const Text('Log exercise'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomSheet extends StatefulWidget {
  final String initialName;
  const _CustomSheet({required this.initialName});

  @override
  State<_CustomSheet> createState() => _CustomSheetState();
}

class _CustomSheetState extends State<_CustomSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _minutes = TextEditingController(text: '30');
  final _calories = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _minutes.dispose();
    _calories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? positive(String? v) =>
        (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter a number';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Custom activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Activity name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    validator: positive,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _calories,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Calories burned',
                    ),
                    validator: positive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, (
                  _name.text.trim(),
                  int.parse(_minutes.text),
                  double.parse(_calories.text),
                ));
              },
              child: const Text('Log exercise'),
            ),
          ],
        ),
      ),
    );
  }
}
