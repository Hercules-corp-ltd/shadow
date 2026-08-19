import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';

/// "Heading + optional action" row used to title lists.
///
/// The rule to the right of the title is the whole change. A bare heading over
/// a list is the default in every app; the line makes the heading read as a
/// band cut across the page, which is the language the home screen's
/// colonnade already speaks. It fades out as it travels, so it ends rather
/// than stopping at an arbitrary margin.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: ShadowColors.primary, size: 22),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: ShadowTypography.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: ShadowTypography.bodySm),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            // Sits on the title's baseline rather than the middle of a
            // two-line block, so a subtitle does not drag the rule downward.
            padding: const EdgeInsets.only(left: 14, top: 13),
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    ShadowColors.edge,
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
