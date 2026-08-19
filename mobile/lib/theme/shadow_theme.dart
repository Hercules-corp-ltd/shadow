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
      // Every plain text field in the app. Cut into the page rather than
      // stacked on it: the fill is darker than what surrounds it and the edge
      // is a hairline of caught light, which is the same thing the home
      // screen's address slot does. It was an opaque grey block with a solid
      // border, i.e. a panel floating above the page, and it made every form
      // read as stock Material.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ShadowColors.recess,
        hintStyle: ShadowTypography.body.copyWith(color: ShadowColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          borderSide: const BorderSide(color: ShadowColors.edge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          borderSide: const BorderSide(color: ShadowColors.edge),
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
          side: const BorderSide(color: ShadowColors.edge),
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
      // Raised, so unlike the cut surfaces this one is *lighter* than the
      // page. Kept faint: a bare Material Card is a fallback, and anything
      // that matters is a GlassCard, which paints its own top-edge highlight
      // and shadow.
      cardTheme: CardThemeData(
        color: ShadowColors.surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.lg),
          side: const BorderSide(color: ShadowColors.edge),
        ),
      ),
      // Seven call sites used to pass their own backgroundColor here, so the
      // sheets drifted apart from the app and from each other. One definition:
      // near-opaque, because a sheet covers a page and has to be readable over
      // anything, with the same lit edge as every other raised surface.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xF216171C),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: ShadowColors.edge),
        ),
      ),
      // Nearly opaque, deliberately. A snack bar lands over whatever the user
      // was reading, and a translucent one has to be legible against text,
      // video and a white page alike. The lit edge is what ties it back to
      // everything else.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xF21A1B20),
        contentTextStyle: ShadowTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          side: const BorderSide(color: ShadowColors.edge),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      // Same reasoning as the snack bar, plus one more: a dialog is the app
      // asking a question it needs answered, and a surface you can see through
      // undercuts that. Opaque body, lit edge.
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF16171C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.xl),
          side: const BorderSide(color: ShadowColors.edge),
        ),
        titleTextStyle: ShadowTypography.h3,
        contentTextStyle: ShadowTypography.body,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ShadowColors.primary,
        linearTrackColor: ShadowColors.recess,
      ),
      // The control that appears most often on the settings screens, and the
      // one that gave them away. An off switch is a groove: dark, translucent,
      // edged. On, it fills with the accent, so the difference between the two
      // states is light arriving rather than a grey turning orange.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return ShadowColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ShadowColors.primary;
          return ShadowColors.recess;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return ShadowColors.edge;
        }),
      ),
      // Storage's two sliders were the last untouched Material control in the
      // app: a fat thumb with a ripple halo, and a row of tick dots down the
      // inactive track that implied discrete stops the values do not have.
      // What is left is a groove with light filling it up to the value.
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: ShadowColors.primary,
        inactiveTrackColor: ShadowColors.recess,
        thumbColor: ShadowColors.primary,
        overlayColor: ShadowColors.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        valueIndicatorColor: const Color(0xFF16171C),
        valueIndicatorTextStyle: ShadowTypography.label,
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
      // Filter chips: History, Activity, the domain screens. Unselected is a
      // cut, selected is the same cut with light in it.
      chipTheme: ChipThemeData(
        backgroundColor: ShadowColors.recess,
        selectedColor: ShadowColors.primarySoft,
        labelStyle: ShadowTypography.label,
        side: const BorderSide(color: ShadowColors.edge),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadowRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
