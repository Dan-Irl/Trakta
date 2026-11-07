import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// The single place that turns design/DESIGN.md into Material widgets.
/// Screens use stock widgets (Card, FilledButton, TextFormField…) and get the
/// Trakta look from here; avoid per-widget colours, radii and text sizes.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme() : _lightScheme();
  // Merged onto the platform's typography, so every style (also those
  // handed straight to component themes below) carries the platform font:
  // Roboto on Android, SF Pro on iOS.
  final platform = Typography.material2021(platform: defaultTargetPlatform);
  final text = (dark ? platform.white : platform.black).merge(_textTheme(scheme.onSurface));
  const base = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.base)));
  final hairline = BorderSide(color: scheme.outlineVariant);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [dark ? TraktaColors.dark : TraktaColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
        side: hairline,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
        shape: const WidgetStatePropertyAll(base),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return scheme.onSurface.withValues(alpha: 0.12);
          if (s.contains(WidgetState.pressed)) return scheme.secondary;
          return scheme.primary;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: base,
        side: BorderSide(color: scheme.outline),
        foregroundColor: dark ? scheme.onSurface : scheme.secondary,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: base, textStyle: text.labelLarge)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.card))),
      extendedTextStyle: text.labelLarge,
      // Flat, like the rest of the app (DESIGN.md "Depth").
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
      border: _inputBorder(scheme.outline),
      enabledBorder: _inputBorder(scheme.outline),
      focusedBorder: _inputBorder(scheme.primary, 2),
      errorBorder: _inputBorder(scheme.error),
      focusedErrorBorder: _inputBorder(scheme.error, 2),
      suffixStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: hairline),
      side: hairline,
      color: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.secondary : scheme.surfaceContainerLowest,
      ),
      labelStyle: text.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onSecondary : scheme.onSurface,
        ),
      ),
      checkmarkColor: scheme.onSecondary,
    ),
    // Expanding tiles sit inside cards; no extra divider lines when opened.
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: Space.md)),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.card))),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: base,
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(Radii.base)),
      borderSide: BorderSide(color: color, width: width),
    );

/// The ten colours from DESIGN.md; Material derives the remaining slots
/// (containers, inverse colours) from [Palette.primary].
ColorScheme _lightScheme() => ColorScheme.fromSeed(seedColor: Palette.primary).copyWith(
      primary: Palette.primary,
      secondary: Palette.navy,
      onSecondary: Colors.white,
      tertiary: Palette.positive,
      error: Palette.error,
      surface: Palette.background,
      onSurface: Palette.navy,
      onSurfaceVariant: Palette.muted,
      surfaceContainerLowest: Palette.surface,
      surfaceContainerLow: Palette.surface,
      surfaceContainer: Palette.subtle,
      outline: Palette.border,
      outlineVariant: Palette.border,
    );

/// DESIGN.md only specifies light mode; dark is derived from the brand blue.
ColorScheme _darkScheme() => ColorScheme.fromSeed(seedColor: Palette.primary, brightness: Brightness.dark);

/// Type scale from DESIGN.md. No font family: Roboto on Android, SF Pro on
/// iOS. Tabular figures so amounts line up in columns.
TextTheme _textTheme(Color color) {
  TextStyle s(double size, double height, FontWeight weight) => TextStyle(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  return TextTheme(
    // Hero: one per screen, so proportional figures (tabular looks loose this big).
    displayMedium: s(44, 52, FontWeight.w700).copyWith(fontFeatures: const []),
    displaySmall: s(28, 34, FontWeight.w700), // Stat
    headlineSmall: s(20, 28, FontWeight.w600), // Headline
    titleLarge: s(20, 28, FontWeight.w600), // Headline
    titleMedium: s(16, 24, FontWeight.w600), // Title
    titleSmall: s(14, 20, FontWeight.w600), // Subtitle
    bodyLarge: s(16, 24, FontWeight.w400), // Body large
    bodyMedium: s(14, 20, FontWeight.w400), // Body
    bodySmall: s(12, 16, FontWeight.w400), // Small
    labelLarge: s(14, 20, FontWeight.w500), // Label
  );
}
