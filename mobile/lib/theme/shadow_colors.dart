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

  // The navy card colours and the gold and glass gradients that used to sit
  // here are gone. They came from the original Figma file and named a look
  // the app no longer has: four screens filled a card with navy or gold and
  // set every string on it to white. Colour is light in this app now, so a
  // card that carries an accent is GlassCard.lit and there is nothing left
  // for a second flat palette to describe. Deleted rather than left unused,
  // because an unused colour constant is an invitation.

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

  // Cut into the stone, rather than laid on top of it.
  //
  // Everything you type into or choose from - inputs, chips at rest, switch
  // tracks - is a recess: darker than the page, with a faint lit edge where a
  // cut catches the light. The old vocabulary made all of them *lighter* than
  // the page (an opaque `surfaceElevated` block with a solid border), which is
  // the one thing a hole cannot be, and it read as stock Material on every
  // settings screen. Panels that genuinely sit above the page keep the raised
  // treatment in `GlassCard`.
  //
  // These are deliberately translucent so the app-wide light passes through.
  // A solid grey stops the light dead at its edge and cuts the surface out of
  // the scene, which is most of what made those screens look borrowed.
  static const Color recess = Color(0x47000000); // black 28%
  static const Color recessDeep = Color(0x80000000); // black 50%

  // Lit edges, in three strengths: a hairline on a quiet cut, the standard
  // edge, and the edge of something focused or held.
  static const Color edgeFaint = Color(0x14FFFFFF); // white 8%
  static const Color edge = Color(0x1FFFFFFF); // white 12%
  static const Color edgeBright = Color(0x33FFFFFF); // white 20%

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
}
