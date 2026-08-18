import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF315E72),
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.card),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 2,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.dialog),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadiusTokens.dialog),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.snackbar),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.control),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            AppLayoutTokens.minimumTouchTarget,
            AppLayoutTokens.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadiusTokens.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            AppLayoutTokens.minimumTouchTarget,
            AppLayoutTokens.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadiusTokens.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppLayoutTokens.minimumTouchTarget,
            AppLayoutTokens.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadiusTokens.compact),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppLayoutTokens.minimumTouchTarget,
            AppLayoutTokens.minimumTouchTarget,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.compact),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 3),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
