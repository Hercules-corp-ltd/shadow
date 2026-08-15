import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';

/// Translucent card with subtle border and blur, matching the Figma
/// "Overlay+Border+OverlayBlur" motif.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ShadowSpacing.cardPadding),
    this.radius = ShadowRadius.lg,
    this.onTap,
    this.gradient,
    this.color,
    this.border,
    this.blur = 24,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final BoxBorder? border;
  final double blur;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (gradient == null ? ShadowColors.surfaceGlass : null),
        gradient: gradient,
        borderRadius: borderRadius,
        border: border ??
            Border.all(color: ShadowColors.surfaceGlassBorder, width: 1),
      ),
      child: child,
    );

    final card = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: card,
          ),
        ),
      );
    }

    return Padding(padding: margin ?? EdgeInsets.zero, child: card);
  }
}
