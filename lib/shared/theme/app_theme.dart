import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xLarge = 32.0;
  static const double maxWidth = 720.0;
}

abstract final class AppTheme {
  // Official Flutter Blue seed color
  static const _flutterBlue = Color(0xFF006CD1);

  static ThemeData create(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colors = ColorScheme.fromSeed(
      seedColor: _flutterBlue,
      brightness: brightness,
      // Refined surface tones for a modern premium feel
      surfaceTint: _flutterBlue,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,

      // Typography
      typography: Typography.material2021(platform: TargetPlatform.android),

      // App Bar Styling
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: colors.surfaceTint,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onSurface),
        actionsIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      // Card Theme (Slightly elevated contrast with clean border)
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? colors.surfaceContainerLow
            : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.small,
          //horizontal: AppSpacing.medium,
        ),
      ),

      // Premium Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colors.surfaceContainerHigh
            : colors.surfaceContainerLow.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium + 4,
          vertical: AppSpacing.medium + 2,
        ),
        hintStyle: TextStyle(
          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),

      // Filled Button (Primary CTA)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shadowColor: colors.shadow.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          side: BorderSide(color: colors.outline),
        ),
      ),

      // Navigation Bar (Material 3 Bottom Navigation)
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.onPrimaryContainer);
          }
          return IconThemeData(color: colors.onSurfaceVariant);
        }),
      ),

      // Chips
      chipTheme: ChipThemeData(
        elevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        selectedColor: colors.primaryContainer,
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        labelStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: AppSpacing.large,
      ),
    );
  }
}
