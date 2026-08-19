import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// Small dot + label pill used for status indicators (Mainnet/Devnet/etc.).
///
/// The dot already glows; the pill around it used to be an opaque grey block,
/// so the one lit thing on it was fighting a surface that stopped the app's
/// light dead. The pill is now a cut with a lit edge and the dot's colour
/// bleeding faintly into the fill, which is what a small light inside a groove
/// actually does.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.trailing,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShadowColors.recess,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadowRadius.pill),
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: ShadowTypography.label.copyWith(
                  color: ShadowColors.textPrimary,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
