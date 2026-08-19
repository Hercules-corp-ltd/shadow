import 'package:flutter/material.dart';

import '../theme/shadow_spacing.dart';

/// A surface lit from above.
///
/// ## Why the blur went away
///
/// This used to wrap its contents in a 24-pixel `BackdropFilter`. Over
/// `AmbientLight` that would finally have something to blur — but the pools
/// behind it are already the softest thing on screen, so blurring them
/// changes almost nothing visible while costing a saved layer and an offscreen
/// composite per card, on every frame the light moves. Six of these on a
/// screen is six of them.
///
/// What actually reads as glass is not blur. It is a translucent fill that
/// lets the colour behind bleed through, a bright edge along the top where
/// light catches it, and a shadow underneath. All three are cheap, and unlike
/// the blur they were doing nothing before because there was no light and
/// nothing to catch.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ShadowSpacing.cardPadding),
    this.radius = ShadowRadius.lg,
    this.onTap,
    this.gradient,
    this.color,
    this.border,
    @Deprecated('Blur is no longer used; kept so callers still compile.')
    this.blur = 24,
    this.margin,
  }) : accent = null;

  /// A card that carries an accent colour — a balance, a result, a headline
  /// figure.
  ///
  /// Four screens used to do this by filling the card with
  /// `primaryGradient` and setting every string on it to white. That is a
  /// slab of brand colour with the information painted on top of it, and it
  /// made the least interesting label on each screen the highest-contrast
  /// thing on it. Here the accent is *light*: a pool of it inside the card,
  /// an edge of it, a bloom beneath. The text keeps the app's normal colours,
  /// so whatever the card is actually about stays the brightest thing on it.
  const GlassCard.lit({
    super.key,
    required this.child,
    required Color this.accent,
    this.padding = const EdgeInsets.all(ShadowSpacing.cardPadding),
    this.radius = ShadowRadius.lg,
    this.onTap,
    this.margin,
  })  : gradient = null,
        color = null,
        border = null,
        blur = 0;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final BoxBorder? border;
  final double blur;
  final EdgeInsetsGeometry? margin;

  /// Non-null only for [GlassCard.lit].
  final Color? accent;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.radius);
    final tappable = widget.onTap != null;
    final accent = widget.accent;

    final decorated = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        // A vertical fall rather than the old flat fill: brighter along the
        // top edge, darker at the bottom, which is what a surface under a
        // light overhead actually does.
        gradient: accent != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: widget.onTap != null && _pressed
                      ? 0.24
                      : 0.18),
                  accent.withValues(alpha: 0.045),
                ],
              )
            : widget.gradient ??
            (widget.color == null
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: _pressed ? 0.10 : 0.075),
                      Colors.white.withValues(alpha: 0.025),
                    ],
                  )
                : null),
        color: widget.color,
        borderRadius: borderRadius,
        border: widget.border ??
            Border.all(
              color: accent != null
                  ? accent.withValues(alpha: _pressed ? 0.42 : 0.30)
                  : Colors.white.withValues(alpha: _pressed ? 0.20 : 0.13),
              width: 1,
            ),
        boxShadow: <BoxShadow>[
          // The shadow the app is named after. Soft and offset downward, so
          // the card sits above the light rather than being painted onto it.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: _pressed ? 10 : 22,
            offset: Offset(0, _pressed ? 3 : 10),
            spreadRadius: -6,
          ),
          if (accent != null)
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 40,
              offset: const Offset(0, 10),
              spreadRadius: -12,
            ),
        ],
      ),
      child: widget.child,
    );

    if (!tappable) {
      return Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: decorated,
      );
    }

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            widget.onTap!.call();
          },
          child: AnimatedScale(
            // Small enough to feel like the surface gave, rather than like
            // the card is a button pretending to be a surface.
            scale: _pressed ? 0.985 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: decorated,
          ),
        ),
      ),
    );
  }
}
