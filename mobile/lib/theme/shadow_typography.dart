import 'package:flutter/material.dart';
import 'shadow_colors.dart';

/// Typography system for Shadow Browser.
///
/// - Display (SHADOW logo, onboarding headings): Cinzel (classical serif).
/// - Body / UI: Inter (clean sans-serif).
/// - Mono (addresses, keys, derived credentials): JetBrains Mono.
///
/// All three ship as variable fonts bundled under `assets/fonts/`. Nothing is
/// fetched at runtime — a browser that sells privacy must not phone a font CDN
/// on first launch, and bundling also keeps iOS builds deterministic offline.
class ShadowTypography {
  ShadowTypography._();

  static const String displayFamily = 'Cinzel';
  static const String bodyFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  /// Variable fonts need the `wght` axis set explicitly. Setting only
  /// [FontWeight] leaves the axis at its default instance on some platforms,
  /// so every weight here is applied twice: once for Flutter's own matching
  /// and once as a font variation the renderer acts on.
  static TextStyle _style(
    String family, {
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      letterSpacing: letterSpacing,
      height: height,
      color: color ?? ShadowColors.textPrimary,
    );
  }

  // Display (serif)
  static TextStyle get displayXL => _style(
        displayFamily,
        size: 48,
        weight: FontWeight.w900,
        letterSpacing: 2,
        height: 1.1,
      );

  static TextStyle get displayLg => _style(
        displayFamily,
        size: 36,
        weight: FontWeight.w800,
        letterSpacing: 1.5,
        height: 1.15,
      );

  static TextStyle get displayMd => _style(
        displayFamily,
        size: 28,
        weight: FontWeight.w700,
        letterSpacing: 1,
        height: 1.2,
      );

  // Body / UI (sans)
  static TextStyle get h1 =>
      _style(bodyFamily, size: 28, weight: FontWeight.w700, height: 1.3);

  static TextStyle get h2 =>
      _style(bodyFamily, size: 24, weight: FontWeight.w700, height: 1.3);

  static TextStyle get h3 =>
      _style(bodyFamily, size: 20, weight: FontWeight.w600, height: 1.3);

  static TextStyle get h4 =>
      _style(bodyFamily, size: 17, weight: FontWeight.w600, height: 1.3);

  static TextStyle get bodyLg =>
      _style(bodyFamily, size: 16, weight: FontWeight.w400, height: 1.5);

  static TextStyle get body =>
      _style(bodyFamily, size: 14, weight: FontWeight.w400, height: 1.5);

  static TextStyle get bodySm => _style(
        bodyFamily,
        size: 13,
        weight: FontWeight.w400,
        height: 1.4,
        color: ShadowColors.textSecondary,
      );

  static TextStyle get caption => _style(
        bodyFamily,
        size: 12,
        weight: FontWeight.w400,
        height: 1.3,
        color: ShadowColors.textTertiary,
      );

  static TextStyle get label =>
      _style(bodyFamily, size: 13, weight: FontWeight.w500, height: 1.3);

  static TextStyle get button => _style(
        bodyFamily,
        size: 15,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  static TextStyle get mono =>
      _style(monoFamily, size: 13, weight: FontWeight.w400);
}
