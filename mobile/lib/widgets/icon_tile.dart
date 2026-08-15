import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// Colored rounded-square icon with a label below, matching the feature
/// grid on the Shadow home page.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 56,
  });

  final String label;
  final Widget icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShadowRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(ShadowRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white, size: 26),
                    child: icon,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: ShadowTypography.bodySm.copyWith(
                  color: ShadowColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
