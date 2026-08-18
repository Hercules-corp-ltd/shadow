import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shadow_colors.dart';
import 'shadow_spacing.dart';
import 'shadow_typography.dart';

/// Global Material 3 theme for the Shadow Browser mobile app.
class ShadowTheme {
  ShadowTheme._();

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: ShadowColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);

    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: ShadowColors.primary,
      onPrimary: Colors.white,
      secondary: ShadowColors.tilePurple,
      onSecondary: Colors.white,
      surface: ShadowColors.surface,
      onSurface: ShadowColors.textPrimary,
      error: ShadowColors.error,
      onError: Colors.white,
      outline: ShadowColors.border,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      // Transparent so the app-wide AmbientLight shows through. The light
      // paints its own black base, so nothing is left unpainted.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: ShadowColors.background,
      textTheme: base.textTheme.apply(
        fontFamily: ShadowTypography.bodyFamily,
        bodyColor: ShadowColors.textPrimary,
        displayColor: ShadowColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: ShadowTypography.h3,
        iconTheme: const IconThemeData(color: ShadowColors.textPrimary),
      ),
      iconTheme: const IconThemeData(color: ShadowColors.textPrimary, size: 22),
      dividerTheme: const DividerThemeData(
        color: ShadowColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ShadowColors.surfaceElevated,
        hintStyle: ShadowTypography.body.copyWith(color: ShadowColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          borderSide: const BorderSide(color: ShadowColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          borderSide: const BorderSide(color: ShadowColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          borderSide: const BorderSide(color: ShadowColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          borderSide: const BorderSide(color: ShadowColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ShadowColors.primary,
          foregroundColor: Colors.white,
          textStyle: ShadowTypography.button,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShadowRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ShadowColors.textPrimary,
          side: const BorderSide(color: ShadowColors.border),
          textStyle: ShadowTypography.button,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShadowRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ShadowColors.primary,
          textStyle: ShadowTypography.button,
        ),
      ),
      cardTheme: CardThemeData(
        color: ShadowColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.lg),
          side: const BorderSide(color: ShadowColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ShadowColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ShadowColors.surfaceElevated,
        contentTextStyle: ShadowTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          side: const BorderSide(color: ShadowColors.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ShadowColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.xl),
          side: const BorderSide(color: ShadowColors.border),
        ),
        titleTextStyle: ShadowTypography.h3,
        contentTextStyle: ShadowTypography.body,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ShadowColors.primary,
        linearTrackColor: ShadowColors.borderSubtle,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return ShadowColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ShadowColors.primary;
          return ShadowColors.surfaceElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(ShadowColors.border),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ShadowColors.primary,
        unselectedLabelColor: ShadowColors.textSecondary,
        labelStyle: ShadowTypography.label.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: ShadowTypography.label,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: ShadowColors.primary, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ShadowColors.surfaceElevated,
        selectedColor: ShadowColors.primarySoft,
        labelStyle: ShadowTypography.label,
        side: const BorderSide(color: ShadowColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
