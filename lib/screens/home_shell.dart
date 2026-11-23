import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'exercise_screen.dart';
import 'food_screens.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';

class HomeShell extends StatefulWidget {
  final AppUser user;
  final Profile profile;
  const HomeShell({super.key, required this.user, required this.profile});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  DateTime _day = DateTime.now();
  bool _stepsStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_stepsStarted) {
      _stepsStarted = true;
      _startSteps();
    }
  }

  Future<void> _startSteps() async {
    final services = Services.of(context);
    final uid = widget.user.uid;
    services.steps.onPersist = (count) => services.repo
        .updateDay(uid, dayKeyOf(DateTime.now()), steps: count)
        .catchError((Object e) => debugPrint('Saving steps failed: $e'));
    if (!widget.profile.stepTracking) return;
    try {
      final saved = await services.repo
          .watchDay(uid, dayKeyOf(DateTime.now()))
          .first;
      await services.steps.resume(savedSteps: saved.steps);
    } catch (e) {
      debugPrint('Starting step tracking failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Services.of(context).steps.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user.uid;
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: switch (_tab) {
                  0 => DashboardScreen(
                    user: widget.user,
                    profile: widget.profile,
                    day: _day,
                    onDayChanged: (d) => setState(() => _day = d),
                  ),
                  1 => ProgressScreen(uid: uid, profile: widget.profile),
                  _ => ProfileScreen(
                    user: widget.user,
                    profile: widget.profile,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _FloatingNav(
        tab: _tab,
        onTab: (i) => setState(() => _tab = i),
        onLog: () => showAddSheet(
          context,
          widget.profile,
          LogTarget(
            uid,
            dayKeyOf(_tab == 0 ? _day : DateTime.now()),
            research: widget.profile.shareForResearch,
          ),
        ),
      ),
    );
  }
}

/// Frosted pill with the three tabs, plus a round gradient Log button.
class _FloatingNav extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onLog;
  const _FloatingNav({
    required this.tab,
    required this.onTab,
    required this.onLog,
  });

  static const _items = [
    ('Today', Icons.today_outlined, Icons.today_rounded),
    ('Progress', Icons.insights_outlined, Icons.insights_rounded),
    ('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, kFloatingNavMargin),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        height: kFloatingNavHeight,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh.withValues(
                            alpha: 0.82,
                          ),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < _items.length; i++)
                              Expanded(
                                flex: tab == i ? 3 : 2,
                                child: Tooltip(
                                  message: _items[i].$1,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(28),
                                    onTap: () => onTab(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 240,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: tab == i
                                            ? scheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            tab == i
                                                ? _items[i].$3
                                                : _items[i].$2,
                                            color: tab == i
                                                ? scheme.onPrimary
                                                : scheme.onSurfaceVariant,
                                          ),
                                          if (tab == i) ...[
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _items[i].$1,
                                                maxLines: 1,
                                                overflow: TextOverflow.fade,
                                                softWrap: false,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: scheme.onPrimary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Log',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      width: kFloatingNavHeight,
                      height: kFloatingNavHeight,
                      decoration: BoxDecoration(
                        gradient: AppColors.brand,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lime.withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: onLog,
                        child: const Icon(
                          Icons.add_rounded,
                          size: 34,
                          color: Color(0xFF10160A),
                        ),
                      ),
                    ),
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

/// The "what do you want to log?" sheet behind the Log button.
Future<void> showAddSheet(
  BuildContext context,
  Profile profile,
  LogTarget target,
) async {
  final action = await showModalBottomSheet<VoidCallback>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      Widget tile(
        IconData icon,
        Color color,
        String title,
        String subtitle,
        VoidCallback run,
      ) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        onTap: () => Navigator.pop(sheet, run),
      );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    target.meal == null
                        ? 'Log something'
                        : 'Add to ${target.meal!.label.toLowerCase()}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              tile(
                Icons.photo_camera_rounded,
                theme.colorScheme.primary,
                'Scan a meal',
                'Take a photo and get calories and macros',
                () => logFromPhoto(context, target, ImageSource.camera),
              ),
              tile(
                Icons.photo_library_rounded,
                AppColors.protein,
                'Choose a photo',
                'Analyze a picture from your gallery',
                () => logFromPhoto(context, target, ImageSource.gallery),
              ),
              tile(
                Icons.auto_awesome_rounded,
                AppColors.carbs,
                'Describe it',
                'Type what you ate and let AI estimate it',
                () => logFromText(context, target),
              ),
              tile(
                Icons.edit_note_rounded,
                AppColors.fat,
                'Add manually',
                'Enter the food and its nutrients yourself',
                () => logManually(context, target),
              ),
              tile(
                Icons.history_rounded,
                AppColors.steps,
                'Recent meals',
                'Re-log something you ate before',
                () => logFromRecent(context, target),
              ),
              if (target.meal == null) ...[
                const Divider(indent: 24, endIndent: 24),
                tile(
                  Icons.fitness_center_rounded,
                  AppColors.burn,
                  'Exercise',
                  'Log a workout and the calories it burned',
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExerciseScreen(
                        uid: target.uid,
                        dayKey: target.dayKey,
                        weightKg: profile.weightKg,
                      ),
                    ),
                  ),
                ),
                tile(
                  Icons.monitor_weight_rounded,
                  AppColors.water,
                  'Weight',
                  'Record a weigh-in',
                  () => showWeightSheet(
                    context,
                    target.uid,
                    profile,
                    target.dayKey,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
  action?.call();
}

/// Records a weigh-in for [dayKey]; today's weigh-in also updates the profile.
Future<void> showWeightSheet(
  BuildContext context,
  String uid,
  Profile profile,
  String dayKey,
) async {
  var weight = profile.weightKg;
  final result = await showModalBottomSheet<double>(
    context: context,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log your weight',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              NumberStepper(
                value: weight,
                min: 30,
                max: 200,
                step: 0.1,
                unit: 'kg',
                onChanged: (v) => setState(() => weight = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, weight),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  final repo = Services.of(context).repo;
  try {
    await repo.updateDay(uid, dayKey, weightKg: result);
    if (dayKey == dayKeyOf(DateTime.now())) {
      await repo.saveProfile(uid, profile.copyWith(weightKg: result));
    }
    if (context.mounted) showMessage(context, 'Weight saved');
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not save. $e');
  }
}
