import 'package:flutter/material.dart';

/// Fixed accent colours for nutrition data; chosen to read on both themes.
class AppColors {
  static const lime = Color(0xFFC8F560);
  static const mint = Color(0xFF5EE6A8);
  static const limeDeep = Color(0xFF3F6D00);
  static const protein = Color(0xFF6C9BFF);
  static const carbs = Color(0xFFFFB547);
  static const fat = Color(0xFFFF6FB5);
  static const burn = Color(0xFFFF7A45);
  static const water = Color(0xFF38BDF8);
  static const steps = Color(0xFFA78BFA);

  /// Brand gradient used on the calorie gauge and the main action button.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lime, mint],
  );
}

const _display = 'Outfit';
const _body = 'Manrope';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.limeDeep,
        brightness: brightness,
      ).copyWith(
        primary: dark ? AppColors.lime : AppColors.limeDeep,
        onPrimary: dark ? const Color(0xFF10160A) : Colors.white,
        surface: dark ? const Color(0xFF0A0C0F) : const Color(0xFFF2F3ED),
        surfaceContainer: dark ? const Color(0xFF14181D) : Colors.white,
        surfaceContainerHigh: dark
            ? const Color(0xFF1C2128)
            : const Color(0xFFEAECE3),
        surfaceContainerHighest: dark
            ? const Color(0xFF272E37)
            : const Color(0xFFDFE2D6),
        onSurface: dark ? const Color(0xFFF3F5F0) : const Color(0xFF12161A),
        onSurfaceVariant: dark
            ? const Color(0xFF98A1AB)
            : const Color(0xFF5B646D),
        outlineVariant: dark
            ? const Color(0xFF242A32)
            : const Color(0xFFDDE0D5),
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: _body,
  );
  final t = base.textTheme;
  TextStyle? display(TextStyle? s, FontWeight w, double spacing) =>
      s?.copyWith(fontFamily: _display, fontWeight: w, letterSpacing: spacing);

  final text = t.copyWith(
    displayLarge: display(t.displayLarge, FontWeight.w700, -1.5),
    displayMedium: display(t.displayMedium, FontWeight.w700, -1.2),
    displaySmall: display(t.displaySmall, FontWeight.w700, -0.8),
    headlineLarge: display(t.headlineLarge, FontWeight.w700, -0.8),
    headlineMedium: display(t.headlineMedium, FontWeight.w700, -0.6),
    headlineSmall: display(t.headlineSmall, FontWeight.w700, -0.4),
    titleLarge: display(t.titleLarge, FontWeight.w600, -0.2),
    titleMedium: display(
      t.titleMedium,
      FontWeight.w600,
      0,
    )?.copyWith(fontSize: 17),
    titleSmall: display(t.titleSmall, FontWeight.w600, 0),
    bodyLarge: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    bodyMedium: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
    bodySmall: t.bodySmall?.copyWith(fontWeight: FontWeight.w500),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    labelSmall: t.labelSmall?.copyWith(fontWeight: FontWeight.w700),
  );
  final button = TextStyle(
    fontFamily: _display,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        textStyle: button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant, width: 1.4),
        textStyle: button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: button.copyWith(fontSize: 15)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(button.copyWith(fontSize: 14)),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      showCheckmark: false,
      labelStyle: text.labelLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    sliderTheme: base.sliderTheme.copyWith(trackHeight: 6),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );
}
