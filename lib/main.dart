import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'firebase_options_ai.dart' as ai;
import 'services/auth_service.dart';
import 'services/data_repo.dart';
import 'services/food_analyzer.dart';
import 'services/key_store.dart';
import 'services/research_store.dart';
import 'services/step_service.dart';
import 'services/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ReemGymApp(services: await _bootstrap()));
}

Future<Services> _bootstrap() async {
  // Null on platforms Firebase is not configured for (desktop): preview mode.
  final options = _optionsOrNull(() => DefaultFirebaseOptions.currentPlatform);
  final keys = SecureKeyStore();
  await keys.read(); // so the UI knows straight away whether a key is saved
  final theme = PrefsThemeStore();
  await theme.load(); // so the first frame already uses the chosen theme
  if (options == null) return Services.preview(keys: keys, theme: theme);
  await Firebase.initializeApp(options: options);

  // Shared Gemini runs in a second, free-plan project; see
  // firebase_options_ai.dart for why.
  final aiOptions = _optionsOrNull(
    () => ai.DefaultFirebaseOptions.currentPlatform,
  );
  FoodAnalyzer shared = NoSharedAnalyzer();
  if (aiOptions != null) {
    try {
      shared = GeminiFoodAnalyzer(
        await Firebase.initializeApp(name: 'ai', options: aiOptions),
      );
    } catch (e) {
      debugPrint('Shared Gemini project failed to start: $e');
    }
  }
  return Services(
    auth: FirebaseAuthService(),
    repo: FirestoreRepo(),
    analyzer: RoutingFoodAnalyzer(keys, shared),
    steps: StepService(),
    keys: keys,
    research: FirebaseResearchStore(),
    preview: false,
    theme: theme,
  );
}

/// The generated options throw on platforms that were not configured.
FirebaseOptions? _optionsOrNull(FirebaseOptions? Function() read) {
  try {
    return read();
  } on UnsupportedError {
    return null;
  }
}
