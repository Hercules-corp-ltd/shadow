import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// Small dot + label pill used for status indicators (Mainnet/Devnet/etc.).
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
      color: ShadowColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadowRadius.pill),
        side: const BorderSide(color: ShadowColors.border),
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
                    BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
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
