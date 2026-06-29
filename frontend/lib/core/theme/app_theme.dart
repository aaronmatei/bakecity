import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// BakeCity's premium theme — warm, bakery-forward, art-directed. Built from
/// explicit brand tokens (not a single seed) so colours hit the brand palette
/// exactly, with a characterful display serif (Fraunces) paired with a clean
/// geometric sans (Plus Jakarta Sans). Full light + dark parity.
class AppTheme {
  const AppTheme._();

  // ---- Palette: light ----
  static const _cream = Color(0xFFFBF7F0); // background
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _espresso = Color(0xFF2B211B); // primary text
  static const _mocha = Color(0xFF8A7E72); // secondary text
  static const _honey = Color(0xFFE0A83D); // accent
  static const _dividerLight = Color(0xFFEDE6DB);

  // ---- Palette: dark ----
  static const _inkBg = Color(0xFF161210);
  static const _surfaceDark = Color(0xFF211B17);
  static const _cloud = Color(0xFFF3ECE2); // text
  static const _ash = Color(0xFFA99E92); // secondary text
  static const _dividerDark = Color(0xFF322A24);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: _honey,
      brightness: brightness,
    ).copyWith(
      primary: _honey,
      onPrimary: isLight ? _espresso : const Color(0xFF1B1410),
      secondary: isLight ? const Color(0xFFB5384F) : const Color(0xFFE0566E),
      onSecondary: isLight ? Colors.white : const Color(0xFF2B0A10),
      surface: isLight ? _surfaceLight : _surfaceDark,
      onSurface: isLight ? _espresso : _cloud,
      onSurfaceVariant: isLight ? _mocha : _ash,
      outlineVariant: isLight ? _dividerLight : _dividerDark,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    final scaffoldBg = isLight ? _cream : _inkBg;
    final ext = isLight ? BakeColors.light : BakeColors.dark;

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBg,
      extensions: [ext],
      textTheme: _textTheme(base.textTheme, scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? Colors.white
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
    );
  }

  /// Display serif (Fraunces) for headings/section titles; geometric sans
  /// (Plus Jakarta Sans) for everything else. Sentence case, two weights.
  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    final sans = GoogleFonts.plusJakartaSansTextTheme(base)
        .apply(bodyColor: onSurface, displayColor: onSurface);
    TextStyle display(TextStyle? s) =>
        GoogleFonts.fraunces(textStyle: s, fontWeight: FontWeight.w600, color: onSurface);
    return sans.copyWith(
      displayLarge: display(sans.displayLarge),
      displayMedium: display(sans.displayMedium),
      displaySmall: display(sans.displaySmall),
      headlineLarge: display(sans.headlineLarge),
      headlineMedium: display(sans.headlineMedium),
      headlineSmall: display(sans.headlineSmall),
      titleLarge: display(sans.titleLarge),
    );
  }
}
