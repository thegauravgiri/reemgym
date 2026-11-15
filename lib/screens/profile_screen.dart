import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models.dart';
import '../nutrition_calc.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'food_screens.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppUser user;
  final Profile profile;
  const ProfileScreen({super.key, required this.user, required this.profile});

  Future<void> _save(BuildContext context, Profile updated) async {
    try {
      await Services.of(context).repo.saveProfile(user.uid, updated);
    } catch (e) {
      if (context.mounted) showMessage(context, 'Could not save. $e');
    }
  }

  Future<void> _editNumber(
    BuildContext context,
    String label,
    String unit,
    int current,
    Profile Function(int) apply,
  ) async {
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: unit),
          onSubmitted: (v) => Navigator.pop(dialog, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialog, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0 || !context.mounted) return;
    await _save(context, apply(value));
  }

  Future<void> _toggleSteps(BuildContext context, bool on) async {
    final services = Services.of(context);
    if (!on) {
      services.steps.stop();
      await _save(context, profile.copyWith(stepTracking: false));
      return;
    }
    final saved = await services.repo
        .watchDay(user.uid, dayKeyOf(DateTime.now()))
        .first;
    final ok = await services.steps.enable(savedSteps: saved.steps);
    if (!context.mounted) return;
    if (ok) {
      await _save(context, profile.copyWith(stepTracking: true));
    } else {
      showMessage(
        context,
        services.steps.supported
            ? 'Step counting needs motion or health access. Allow it in '
                  'your phone settings and try again.'
            : 'Step counting works on an Android phone or iPhone.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final services = Services.of(context);
    final p = profile;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    Widget info(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    Widget target(
      String label,
      int value,
      String unit,
      Color color,
      Profile Function(int) apply,
    ) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      minLeadingWidth: 10,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${formatNumber(value)} $unit',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () => _editNumber(context, label, unit, value, apply),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('Profile', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        Panel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                foregroundImage: user.photoUrl == null
                    ? null
                    : NetworkImage(user.photoUrl!),
                onForegroundImageError: user.photoUrl == null
                    ? null
                    : (_, _) {},
                child: Text(
                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: theme.textTheme.titleLarge),
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        heading('Your body'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              info('Age', '${p.age} years'),
              info('Height', '${p.heightCm.round()} cm'),
              info('Weight', '${p.weightKg.toStringAsFixed(1)} kg'),
              info('BMI', bmi(p.weightKg, p.heightCm).toStringAsFixed(1)),
              info('Activity', p.activity.label),
              info(
                'Goal',
                p.goal == Goal.maintain
                    ? p.goal.label
                    : '${p.goal.label} to '
                          '${p.targetWeightKg.toStringAsFixed(1)} kg',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OnboardingScreen(user: user, existing: p),
                    ),
                  ),
                  child: const Text('Update details and rebuild plan'),
                ),
              ),
            ],
          ),
        ),
        heading('Daily targets'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              target(
                'Calories',
                p.calorieTarget,
                'kcal',
                scheme.primary,
                (v) => p.copyWith(calorieTarget: v),
              ),
              target(
                'Protein',
                p.proteinTarget,
                'g',
                AppColors.protein,
                (v) => p.copyWith(proteinTarget: v),
              ),
              target(
                'Carbs',
                p.carbsTarget,
                'g',
                AppColors.carbs,
                (v) => p.copyWith(carbsTarget: v),
              ),
              target(
                'Fat',
                p.fatTarget,
                'g',
                AppColors.fat,
                (v) => p.copyWith(fatTarget: v),
              ),
              target(
                'Water',
                p.waterGoalMl,
                'ml',
                AppColors.water,
                (v) => p.copyWith(waterGoalMl: v),
              ),
              target(
                'Steps',
                p.stepGoal,
                'steps',
                AppColors.steps,
                (v) => p.copyWith(stepGoal: v),
              ),
            ],
          ),
        ),
        heading('Tracking'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            title: const Text('Step counting'),
            subtitle: Text(
              services.steps.supported
                  ? 'Counts steps through the day, even while ReemGym is '
                        'closed, and detects walking or running'
                  : 'Available on an Android phone or iPhone',
            ),
            value: p.stepTracking,
            onChanged: (on) => _toggleSteps(context, on),
          ),
        ),
        heading('Food analysis'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: services.keys.hasKey,
                builder: (context, has, _) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.key_rounded),
                  title: const Text('Gemini API key'),
                  subtitle: Text(
                    has
                        ? 'Using your own key on this device'
                        : 'Using the shared free allowance. Add your own '
                              'key for a personal allowance.',
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => showKeySheet(context),
                ),
              ),
              const Divider(indent: 18, endIndent: 18),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                title: const Text('Share meals for research'),
                subtitle: const Text(
                  'Saves your meal photos, the AI estimates and your corrections '
                  'so they can be used to improve food recognition and for '
                  'research. Off by default; turn it off any time.',
                ),
                value: p.shareForResearch,
                onChanged: (on) =>
                    _save(context, p.copyWith(shareForResearch: on)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            services.steps.stop();
            services.auth.signOut();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 16),
        Text(
          'Calorie, macro and burn figures are estimates, not medical '
          'advice.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
