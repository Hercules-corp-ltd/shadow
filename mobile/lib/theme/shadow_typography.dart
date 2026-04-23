import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shadow_colors.dart';

/// Typography system for Shadow Browser.
///
/// - Display (SHADOW logo, onboarding headings): Cinzel (classical serif).
/// - Body / UI: Inter (clean sans-serif).
class ShadowTypography {
  ShadowTypography._();

  static TextStyle get _displayBase =>
      GoogleFonts.cinzel(color: ShadowColors.textPrimary);

  static TextStyle get _bodyBase =>
      GoogleFonts.inter(color: ShadowColors.textPrimary);

  // Display (serif)
  static TextStyle get displayXL => _displayBase.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        height: 1.1,
      );

  static TextStyle get displayLg => _displayBase.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        height: 1.15,
      );

  static TextStyle get displayMd => _displayBase.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        height: 1.2,
      );

  // Body / UI (sans)
  static TextStyle get h1 =>
      _bodyBase.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3);

  static TextStyle get h2 =>
      _bodyBase.copyWith(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3);

  static TextStyle get h3 =>
      _bodyBase.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get h4 =>
      _bodyBase.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get bodyLg =>
      _bodyBase.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get body =>
      _bodyBase.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get bodySm => _bodyBase.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: ShadowColors.textSecondary,
      );

  static TextStyle get caption => _bodyBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: ShadowColors.textTertiary,
      );

  static TextStyle get label =>
      _bodyBase.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3);

  static TextStyle get button => _bodyBase.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        color: ShadowColors.textPrimary,
      );
}
