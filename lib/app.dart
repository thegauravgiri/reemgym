import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/data_repo.dart';
import 'services/food_analyzer.dart';
import 'services/key_store.dart';
import 'services/research_store.dart';
import 'services/step_service.dart';
import 'services/theme_store.dart';
import 'theme.dart';

/// The app's backing services. In preview mode (Firebase not configured yet)
/// the in-memory implementations are used instead.
class Services {
  final AuthService auth;
  final DataRepo repo;
  final FoodAnalyzer analyzer;
  final StepService steps;
  final KeyStore keys;
  final ResearchStore research;

  /// Light, dark or system appearance, saved per device.
  final ThemeStore theme;
  final bool preview;

  Services({
    required this.auth,
    required this.repo,
    required this.analyzer,
    required this.steps,
    required this.keys,
    required this.research,
    required this.preview,
    ThemeStore? theme,
  }) : theme = theme ?? MemoryThemeStore();

  /// [keys] defaults to an in-memory store; the real app passes the secure
  /// one so a personal Gemini key works even before Firebase is connected.
  factory Services.preview({KeyStore? keys, ThemeStore? theme}) {
    final store = keys ?? MemoryKeyStore();
    return Services(
      auth: MemoryAuthService(),
      repo: MemoryRepo(),
      analyzer: RoutingFoodAnalyzer(store, DemoFoodAnalyzer()),
      steps: StepService(),
      keys: store,
      research: NoResearchStore(),
      preview: true,
      theme: theme,
    );
  }

  static Services of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ServicesScope>()!.services;
}

class _ServicesScope extends InheritedWidget {
  final Services services;
  const _ServicesScope({required this.services, required super.child});

  @override
  bool updateShouldNotify(_ServicesScope old) => old.services != services;
}

class ReemGymApp extends StatelessWidget {
  final Services services;
  const ReemGymApp({super.key, required this.services});

  // Built once so switching modes only swaps between two fixed themes.
  static final _light = buildTheme(Brightness.light);
  static final _dark = buildTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return _ServicesScope(
      services: services,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: services.theme.mode,
        builder: (context, mode, _) => MaterialApp(
          title: 'ReemGym',
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          themeMode: mode,
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Decides between sign-in, onboarding and the main app.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final Stream<AppUser?> _users = Services.of(context).auth.userChanges;
  String? _uid;
  Stream<Profile?>? _profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _users,
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = auth.data;
        if (user == null) {
          _uid = null;
          return const AuthScreen();
        }
        if (_uid != user.uid) {
          _uid = user.uid;
          _profile = Services.of(context).repo.watchProfile(user.uid);
        }
        return StreamBuilder<Profile?>(
          key: ValueKey(user.uid),
          stream: _profile,
          builder: (context, snap) {
            if (snap.hasError) {
              return _LoadError(error: '${snap.error}');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }
            final profile = snap.data;
            if (profile == null) return OnboardingScreen(user: user);
            return HomeShell(user: user, profile: profile);
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _LoadError extends StatelessWidget {
  final String error;
  const _LoadError({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load your profile',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check that Cloud Firestore is created and its security '
                'rules are published.\n\n$error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Services.of(context).auth.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
