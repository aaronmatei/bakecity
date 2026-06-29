import 'package:flutter/material.dart';

/// Design tokens for BakeCity's premium UI. Everything visual — colour beyond
/// the [ColorScheme], spacing, radii, motion, elevation — is sourced here so no
/// widget hardcodes a literal. Brightness-dependent colours live in
/// [BakeColors] extension; the rest are brightness-independent constants.

/// 8pt spacing grid.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 28; // vertical gap between rails
  static const double screenH = 20; // default horizontal screen padding
}

/// Corner radii. Cards 16–24, chips/pills 12, avatars full-round.
abstract final class Radii {
  static const double chip = 12;
  static const double card = 20;
  static const double cardLg = 24;
  static const double sheet = 28;
  static const Radius card_ = Radius.circular(card);
  static const BorderRadius cardBorder = BorderRadius.all(Radius.circular(card));
  static const BorderRadius chipBorder = BorderRadius.all(Radius.circular(chip));
}

/// Motion durations and curves. Fast, eased, never bouncy-everywhere.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 480);
  static const Duration stagger = Duration(milliseconds: 50);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

/// Brand colours not expressible through [ColorScheme], tuned per brightness.
/// Read via `Theme.of(context).extension<BakeColors>()!` or `context.bake`.
@immutable
class BakeColors extends ThemeExtension<BakeColors> {
  const BakeColors({
    required this.berry,
    required this.onBerry,
    required this.success,
    required this.star,
    required this.scrim,
    required this.shadow,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  /// Secondary accent for offers/sales.
  final Color berry;
  final Color onBerry;
  final Color success;

  /// Rating-star fill.
  final Color star;

  /// Gradient scrim colour laid over imagery for text legibility.
  final Color scrim;

  /// Soft card shadow colour (already alpha-tuned).
  final Color shadow;
  final Color shimmerBase;
  final Color shimmerHighlight;

  static const BakeColors light = BakeColors(
    berry: Color(0xFFB5384F),
    onBerry: Color(0xFFFFFFFF),
    success: Color(0xFF1D9E75),
    star: Color(0xFFE0A83D),
    scrim: Color(0xCC000000),
    shadow: Color(0x14000000), // ~8% black, soft
    shimmerBase: Color(0xFFEDE6DB),
    shimmerHighlight: Color(0xFFF8F3EC),
  );

  static const BakeColors dark = BakeColors(
    berry: Color(0xFFE0566E),
    onBerry: Color(0xFF2B0A10),
    success: Color(0xFF2BB98A),
    star: Color(0xFFE7B65A),
    scrim: Color(0xD9000000),
    shadow: Color(0x33000000),
    shimmerBase: Color(0xFF2A221D),
    shimmerHighlight: Color(0xFF3A302A),
  );

  /// Soft, single-direction, low-spread card shadow.
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadow,
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  @override
  BakeColors copyWith({
    Color? berry,
    Color? onBerry,
    Color? success,
    Color? star,
    Color? scrim,
    Color? shadow,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) =>
      BakeColors(
        berry: berry ?? this.berry,
        onBerry: onBerry ?? this.onBerry,
        success: success ?? this.success,
        star: star ?? this.star,
        scrim: scrim ?? this.scrim,
        shadow: shadow ?? this.shadow,
        shimmerBase: shimmerBase ?? this.shimmerBase,
        shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      );

  @override
  BakeColors lerp(ThemeExtension<BakeColors>? other, double t) {
    if (other is! BakeColors) return this;
    return BakeColors(
      berry: Color.lerp(berry, other.berry, t)!,
      onBerry: Color.lerp(onBerry, other.onBerry, t)!,
      success: Color.lerp(success, other.success, t)!,
      star: Color.lerp(star, other.star, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}

/// Terse theme accessors: `context.cs`, `context.tt`, `context.bake`.
extension BakeContext on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  BakeColors get bake => Theme.of(this).extension<BakeColors>() ?? BakeColors.light;

  /// Whether the platform/app asks for reduced motion.
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}
