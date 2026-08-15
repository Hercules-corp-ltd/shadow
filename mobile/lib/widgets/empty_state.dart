import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';
import 'shadow_button.dart';

/// A reusable "nothing here yet" state with icon, message, and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ShadowColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: ShadowColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: ShadowTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: ShadowTypography.bodySm,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ShadowButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
