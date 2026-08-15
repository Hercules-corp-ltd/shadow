import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// A generic "icon + title + subtitle + trailing" card used in history,
/// bookmarks, downloads, recent activity, etc.
class ListItemCard extends StatelessWidget {
  const ListItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingColor,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.statusLabel,
    this.statusColor,
    this.timeLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Color? leadingColor;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? statusLabel;
  final Color? statusColor;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShadowColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadowRadius.md),
        side: const BorderSide(color: ShadowColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (leadingIcon != null)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (leadingColor ?? ShadowColors.primary)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(ShadowRadius.sm),
                  ),
                  child: Icon(
                    leadingIcon,
                    color: leadingColor ?? ShadowColors.primary,
                    size: 20,
                  ),
                ),
              if (leading != null || leadingIcon != null)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: ShadowTypography.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null ||
                        timeLabel != null ||
                        statusLabel != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle(
                        style: ShadowTypography.bodySm,
                        child: Row(
                          children: [
                            if (timeLabel != null) Text(timeLabel!),
                            if (timeLabel != null && subtitle != null) ...[
                              const SizedBox(width: 6),
                              const Text('•'),
                              const SizedBox(width: 6),
                            ],
                            if (subtitle != null)
                              Expanded(
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (statusLabel != null) ...[
                              if (subtitle != null || timeLabel != null) ...[
                                const SizedBox(width: 6),
                                const Text('•'),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                statusLabel!,
                                style: ShadowTypography.bodySm.copyWith(
                                  color:
                                      statusColor ?? ShadowColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ShadowColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
