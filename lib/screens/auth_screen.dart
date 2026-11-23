import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/fx.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Services.of(context).auth.signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign-in failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = Services.of(context).preview;

    Widget feature(IconData icon, Color color, String title, String text) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    final features = [
      feature(
        Icons.photo_camera_rounded,
        scheme.primary,
        'Snap your plate',
        'AI works out calories, macros and nutrients',
      ),
      feature(
        Icons.local_fire_department_rounded,
        AppColors.burn,
        'Log what you burn',
        'Workouts and steps count toward your day',
      ),
      feature(
        Icons.insights_rounded,
        AppColors.steps,
        'See it add up',
        'A daily plan built around your body and goal',
      ),
    ];

    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 460,
                    minHeight: box.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: AppColors.brand,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.lime.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: ReemMark(
                                  size: 50,
                                  color: Color(0xFF10160A),
                                ),
                              ),
                            ),
                          ).animate().scale(
                            duration: 500.ms,
                            curve: Curves.easeOutBack,
                          ),
                          const SizedBox(height: 28),
                          Text(
                                'Snap it.\nTrack it.',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  height: 1.02,
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 500.ms)
                              .slideY(begin: 0.15),
                          const SizedBox(height: 14),
                          Text(
                            'ReemGym turns a photo of your meal into numbers you '
                            'can act on.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
                          const SizedBox(height: 32),
                          for (var i = 0; i < features.length; i++)
                            features[i]
                                .animate()
                                .fadeIn(
                                  delay: (220 + i * 110).ms,
                                  duration: 450.ms,
                                )
                                .slideX(begin: 0.08),
                          const Spacer(flex: 2),
                          if (preview)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                'Preview mode: nothing is saved after you close '
                                'the app.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          FilledButton(
                            onPressed: _busy ? null : _signIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1F1F1F),
                              disabledBackgroundColor: Colors.white70,
                              minimumSize: const Size.fromHeight(60),
                              elevation: 2,
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF1F1F1F),
                                    ),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GoogleLogo(),
                                      SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          'Continue with Google',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),
                          const SizedBox(height: 14),
                          Text(
                            'Your data syncs to your Google account, so it follows '
                            'you to any device.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
