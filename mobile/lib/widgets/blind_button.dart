import 'package:flutter/material.dart';

import '../theme/blind_colors.dart';
import '../theme/blind_spacing.dart';
import '../theme/blind_typography.dart';

enum BlindButtonVariant { primary, secondary, ghost, danger }

enum BlindButtonSize { sm, md, lg }

/// Primary button used across the Blind app. Supports multiple variants,
/// sizes, leading/trailing icons and loading state.
class BlindButton extends StatelessWidget {
  const BlindButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = BlindButtonVariant.primary,
    this.size = BlindButtonSize.md,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final BlindButtonVariant variant;
  final BlindButtonSize size;
  final IconData? leading;
  final IconData? trailing;
  final bool isLoading;
  final bool expand;

  double get _height => switch (size) {
        BlindButtonSize.sm => 40,
        BlindButtonSize.md => 48,
        BlindButtonSize.lg => 56,
      };

  EdgeInsets get _padding => switch (size) {
        BlindButtonSize.sm => const EdgeInsets.symmetric(horizontal: 16),
        BlindButtonSize.md => const EdgeInsets.symmetric(horizontal: 20),
        BlindButtonSize.lg => const EdgeInsets.symmetric(horizontal: 24),
      };

  @override
  Widget build(BuildContext context) {
    final bg = switch (variant) {
      BlindButtonVariant.primary => BlindColors.primary,
      BlindButtonVariant.secondary => BlindColors.surfaceElevated,
      BlindButtonVariant.ghost => Colors.transparent,
      BlindButtonVariant.danger => BlindColors.error,
    };

    final fg = switch (variant) {
      BlindButtonVariant.primary => Colors.white,
      BlindButtonVariant.secondary => BlindColors.textPrimary,
      BlindButtonVariant.ghost => BlindColors.textPrimary,
      BlindButtonVariant.danger => Colors.white,
    };

    final border = switch (variant) {
      BlindButtonVariant.secondary =>
        const BorderSide(color: BlindColors.border),
      BlindButtonVariant.ghost =>
        const BorderSide(color: BlindColors.border),
      _ => BorderSide.none,
    };

    final textStyle = BlindTypography.button.copyWith(color: fg);

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
        borderRadius: BorderRadius.circular(BlindRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Container(
            height: _height,
            padding: _padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BlindRadius.md),
              border: Border.fromBorderSide(border),
              boxShadow: variant == BlindButtonVariant.primary
                  ? [
                      BoxShadow(
                        color: BlindColors.primary.withOpacity(0.35),
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
