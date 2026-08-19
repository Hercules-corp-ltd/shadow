import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

enum ShadowButtonVariant { primary, secondary, ghost, danger }

enum ShadowButtonSize { sm, md, lg }

/// Primary button used across the Shadow app. Supports multiple variants,
/// sizes, leading/trailing icons and loading state.
class ShadowButton extends StatelessWidget {
  const ShadowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ShadowButtonVariant.primary,
    this.size = ShadowButtonSize.md,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final ShadowButtonVariant variant;
  final ShadowButtonSize size;
  final IconData? leading;
  final IconData? trailing;
  final bool isLoading;
  final bool expand;

  double get _height => switch (size) {
        ShadowButtonSize.sm => 40,
        ShadowButtonSize.md => 48,
        ShadowButtonSize.lg => 56,
      };

  EdgeInsets get _padding => switch (size) {
        ShadowButtonSize.sm => const EdgeInsets.symmetric(horizontal: 16),
        ShadowButtonSize.md => const EdgeInsets.symmetric(horizontal: 20),
        ShadowButtonSize.lg => const EdgeInsets.symmetric(horizontal: 24),
      };

  @override
  Widget build(BuildContext context) {
    final bg = switch (variant) {
      ShadowButtonVariant.primary => ShadowColors.primary,
      ShadowButtonVariant.secondary => ShadowColors.surfaceElevated,
      ShadowButtonVariant.ghost => Colors.transparent,
      // Not a filled red slab. A destructive action has to be unmistakable,
      // which is not the same as being the brightest object on the screen —
      // at the bottom of Settings the old one drew the eye before anything
      // a user actually came here to do. Dark body, red edge, red label: it
      // still cannot be confused with the button above it.
      ShadowButtonVariant.danger =>
        ShadowColors.error.withValues(alpha: 0.10),
    };

    final fg = switch (variant) {
      ShadowButtonVariant.primary => Colors.white,
      ShadowButtonVariant.secondary => ShadowColors.textPrimary,
      ShadowButtonVariant.ghost => ShadowColors.textPrimary,
      ShadowButtonVariant.danger => ShadowColors.error,
    };

    final border = switch (variant) {
      ShadowButtonVariant.secondary =>
        const BorderSide(color: ShadowColors.edge),
      ShadowButtonVariant.ghost =>
        const BorderSide(color: ShadowColors.edge),
      ShadowButtonVariant.danger =>
        BorderSide(color: ShadowColors.error.withValues(alpha: 0.55)),
      _ => BorderSide.none,
    };

    final textStyle = ShadowTypography.button.copyWith(color: fg);

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        else ...[
          if (leading != null) ...[
            Icon(leading, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Icon(trailing, size: 18, color: fg),
          ],
        ],
      ],
    );

    final disabled = onPressed == null && !isLoading;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(ShadowRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Container(
            height: _height,
            padding: _padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ShadowRadius.md),
              border: Border.fromBorderSide(border),
              boxShadow: variant == ShadowButtonVariant.primary
                  ? [
                      BoxShadow(
                        color: ShadowColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
