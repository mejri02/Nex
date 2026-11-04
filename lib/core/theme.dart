import 'package:flutter/material.dart';

/// A full UI theme: gradient backdrop + surface colors.
class ThemeSpec {
  const ThemeSpec({
    required this.key,
    required this.bgTop,
    required this.bgBottom,
    required this.surface,
    required this.surfaceHigh,
    this.light = false,
  });

  final String key; // translation key
  final Color bgTop, bgBottom, surface, surfaceHigh;
  final bool light;

  Color get onSurface => light ? const Color(0xFF14161F) : const Color(0xFFF1F3FA);
  Color get muted => light ? const Color(0xFF626777) : const Color(0xFF9AA1B2);
}

const List<ThemeSpec> kThemes = [
  ThemeSpec(key: 'th0', bgTop: Color(0xFF0A0C14), bgBottom: Color(0xFF07080D), surface: Color(0xFF131621), surfaceHigh: Color(0xFF1B1F2E)),
  ThemeSpec(key: 'th1', bgTop: Color(0xFF0A1B33), bgBottom: Color(0xFF050D18), surface: Color(0xFF10253F), surfaceHigh: Color(0xFF173357)),
  ThemeSpec(key: 'th2', bgTop: Color(0xFF000000), bgBottom: Color(0xFF000000), surface: Color(0xFF101010), surfaceHigh: Color(0xFF1A1A1A)),
  ThemeSpec(key: 'th3', bgTop: Color(0xFF0B2A33), bgBottom: Color(0xFF1B0F33), surface: Color(0xFF12202E), surfaceHigh: Color(0xFF1C2D42)),
  ThemeSpec(key: 'th4', bgTop: Color(0xFF2B1020), bgBottom: Color(0xFF14080F), surface: Color(0xFF241320), surfaceHigh: Color(0xFF331C2C)),
  ThemeSpec(key: 'th5', bgTop: Color(0xFFF7F8FC), bgBottom: Color(0xFFE9ECF5), surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFEDEFF7), light: true),
];

const List<int> kAccents = [
  0xFF18D5C2, // teal
  0xFF3B9CFF, // blue
  0xFFA569FF, // violet
  0xFFFF3DA8, // pink
  0xFFFF5A5F, // red
  0xFFFF9F1C, // orange
  0xFFFFD23F, // yellow
  0xFF4ADE80, // green
];

ThemeData buildTheme(ThemeSpec spec, Color accent) {
  final base = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: spec.light ? Brightness.light : Brightness.dark,
  );
  final scheme = base.copyWith(
    primary: accent,
    onPrimary: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark ? Colors.white : Colors.black,
    surface: spec.surface,
    onSurface: spec.onSurface,
    surfaceContainerHighest: spec.surfaceHigh,
    onSurfaceVariant: spec.muted,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: spec.light ? Brightness.light : Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: spec.surface,
    dividerColor: spec.muted.withValues(alpha: 0.2),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: spec.surface.withValues(alpha: 0.94),
      indicatorColor: accent.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, color: spec.onSurface)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: spec.surface.withValues(alpha: 0.94),
      indicatorColor: accent.withValues(alpha: 0.22),
    ),
    dialogTheme: DialogThemeData(backgroundColor: spec.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: spec.surface, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: spec.surfaceHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: spec.surfaceHigh,
      contentTextStyle: TextStyle(color: spec.onSurface),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: spec.muted.withValues(alpha: 0.3),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent.withValues(alpha: 0.35) : null),
    ),
  );
}
