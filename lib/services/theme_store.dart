import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's choice of light, dark or system appearance. It is a display
/// preference for this device, so it lives on the device rather than in the
/// profile and applies before sign-in too.
abstract class ThemeStore {
  /// The current choice; the app rebuilds its theme when it changes.
  ValueNotifier<ThemeMode> get mode;

  /// Loads the saved choice. Call before the first frame to avoid a flash.
  Future<void> load();

  Future<void> set(ThemeMode mode);
}

/// Saved with shared_preferences. Any storage failure falls back to System.
class PrefsThemeStore implements ThemeStore {
  static const _key = 'theme_mode';

  @override
  final mode = ValueNotifier(ThemeMode.system);

  @override
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      mode.value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (e) {
      debugPrint('Reading the saved theme failed: $e');
    }
  }

  @override
  Future<void> set(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (e) {
      debugPrint('Saving the theme failed: $e');
    }
  }
}

/// Keeps the choice for the current run only; used in tests and as a default.
class MemoryThemeStore implements ThemeStore {
  MemoryThemeStore([ThemeMode initial = ThemeMode.system])
    : mode = ValueNotifier(initial);

  @override
  final ValueNotifier<ThemeMode> mode;

  @override
  Future<void> load() async {}

  @override
  Future<void> set(ThemeMode value) async => mode.value = value;
}
