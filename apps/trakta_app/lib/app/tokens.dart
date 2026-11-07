import 'package:flutter/material.dart';

/// Design tokens from design/DESIGN.md. Screens should not use [Palette]
/// directly: read colours through `Theme.of(context)` or [TraktaColors.of] so
/// dark mode keeps working. Radii and spacing are fine to use anywhere.
abstract final class Palette {
  static const primary = Color(0xFF1D58A7);
  static const navy = Color(0xFF0F2942);
  static const muted = Color(0xFF64748B);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const positive = Color(0xFF047857);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFBA1A1A);
}

abstract final class Radii {
  static const base = 8.0; // buttons, inputs, badges
  static const card = 16.0; // cards, sheets, dialogs
}

/// 8 px grid.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0; // screen margin, card padding
  static const lg = 24.0;
  static const xl = 32.0;
  static const fabClearance = 96.0; // list bottom padding so the last row clears the FAB
}

/// Status colours Material's [ColorScheme] has no slot for. Tinted
/// backgrounds use these at 12 % opacity.
@immutable
class TraktaColors extends ThemeExtension<TraktaColors> {
  const TraktaColors({required this.positive, required this.warning});

  /// Deductions, tax-free amounts, completed states.
  final Color positive;

  /// Needs input, in progress.
  final Color warning;

  static const light = TraktaColors(positive: Palette.positive, warning: Palette.warning);
  static const dark = TraktaColors(positive: Color(0xFF34D399), warning: Color(0xFFFBBF24));

  static TraktaColors of(BuildContext context) => Theme.of(context).extension<TraktaColors>()!;

  @override
  TraktaColors copyWith({Color? positive, Color? warning}) =>
      TraktaColors(positive: positive ?? this.positive, warning: warning ?? this.warning);

  @override
  TraktaColors lerp(TraktaColors? other, double t) {
    if (other == null) return this;
    return TraktaColors(
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
