import 'package:flutter/material.dart';

/// Core color palette of the Shadow Browser design system.
/// Derived from the Figma "Shadow Web Browser" file.
class ShadowColors {
  ShadowColors._();

  // Canvas / surfaces
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0B);
  static const Color surfaceElevated = Color(0xFF141519);
  static const Color surfaceGlass = Color(0x1AFFFFFF); // 10% white glass
  static const Color surfaceGlassBorder = Color(0x26FFFFFF); // 15% border

  // Deep blue card background (Convert Your Existing Website)
  static const Color cardNavy = Color(0xFF1A2332);
  static const Color cardNavyBorder = Color(0xFF2A3446);

  // Primary accent (Shadow orange)
  static const Color primary = Color(0xFFF97316);
  static const Color primaryHover = Color(0xFFFB923C);
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color primarySoft = Color(0x33F97316); // 20%

  // Secondary tile colors for feature icons
  static const Color tileBlue = Color(0xFF3B82F6);
  static const Color tilePurple = Color(0xFF8B5CF6);
  static const Color tileGreen = Color(0xFF22C55E);
  static const Color tileOrange = Color(0xFFF97316);
  static const Color tileAmber = Color(0xFFF59E0B);
  static const Color tilePink = Color(0xFFEC4899);
  static const Color tileGray = Color(0xFF64748B);
  static const Color tileCyan = Color(0xFF06B6D4);
  static const Color tileRed = Color(0xFFEF4444);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B6BE);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);

  // Borders & dividers
  static const Color border = Color(0xFF262A31);
  static const Color borderSubtle = Color(0xFF1A1D23);
  static const Color divider = Color(0xFF1F2329);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Network indicator
  static const Color mainnet = Color(0xFF22C55E);
  static const Color devnet = Color(0xFFF59E0B);
  static const Color testnet = Color(0xFF3B82F6);

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
  );

  static const Gradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
  );

  static const Gradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)],
  );

  static const Gradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2332), Color(0xFF0F1620)],
  );
}
