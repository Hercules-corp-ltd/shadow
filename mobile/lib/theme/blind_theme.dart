import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'blind_colors.dart';
import 'blind_spacing.dart';
import 'blind_typography.dart';

/// Global Material 3 theme for the Blind Browser mobile app.
class BlindTheme {
  BlindTheme._();

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: BlindColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: BlindColors.primary,
      onPrimary: Colors.white,
      secondary: BlindColors.tilePurple,
      onSecondary: Colors.white,
      surface: BlindColors.surface,
      onSurface: BlindColors.textPrimary,
      error: BlindColors.error,
      onError: Colors.white,
      outline: BlindColors.border,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BlindColors.background,
      canvasColor: BlindColors.background,
      textTheme: base.textTheme.apply(
        fontFamily: BlindTypography.bodyFamily,
        bodyColor: BlindColors.textPrimary,
        displayColor: BlindColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: BlindTypography.h3,
        iconTheme: const IconThemeData(color: BlindColors.textPrimary),
      ),
      iconTheme: const IconThemeData(color: BlindColors.textPrimary, size: 22),
      dividerTheme: const DividerThemeData(
        color: BlindColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BlindColors.surfaceElevated,
        hintStyle: BlindTypography.body.copyWith(color: BlindColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BlindRadius.md),
          borderSide: const BorderSide(color: BlindColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BlindRadius.md),
          borderSide: const BorderSide(color: BlindColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BlindRadius.md),
          borderSide: const BorderSide(color: BlindColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BlindRadius.md),
          borderSide: const BorderSide(color: BlindColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BlindColors.primary,
          foregroundColor: Colors.white,
          textStyle: BlindTypography.button,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BlindRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BlindColors.textPrimary,
          side: const BorderSide(color: BlindColors.border),
          textStyle: BlindTypography.button,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BlindRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BlindColors.primary,
          textStyle: BlindTypography.button,
        ),
      ),
      cardTheme: CardThemeData(
        color: BlindColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BlindRadius.lg),
          side: const BorderSide(color: BlindColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BlindColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BlindColors.surfaceElevated,
        contentTextStyle: BlindTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BlindRadius.md),
          side: const BorderSide(color: BlindColors.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BlindColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BlindRadius.xl),
          side: const BorderSide(color: BlindColors.border),
        ),
        titleTextStyle: BlindTypography.h3,
        contentTextStyle: BlindTypography.body,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BlindColors.primary,
        linearTrackColor: BlindColors.borderSubtle,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return BlindColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return BlindColors.primary;
          return BlindColors.surfaceElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(BlindColors.border),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: BlindColors.primary,
        unselectedLabelColor: BlindColors.textSecondary,
        labelStyle: BlindTypography.label.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: BlindTypography.label,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: BlindColors.primary, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BlindColors.surfaceElevated,
        selectedColor: BlindColors.primarySoft,
        labelStyle: BlindTypography.label,
        side: const BorderSide(color: BlindColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BlindRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
