import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';
import 'shadow_button.dart';

/// Whether this state reports absence or failure.
///
/// The distinction is the point. "No bookmarks yet" and "we could not reach
/// the server" look identical when both render as an empty list, and the app
/// used to show the former for both — so a dead backend read as an empty
/// account across nine screens.
enum EmptyStateTone {
  /// Nothing is here, and that is a legitimate answer.
  neutral,

  /// Something went wrong and we do not know what is here.
  error,
}

/// A reusable "nothing here yet" state with icon, message, and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = EmptyStateTone.neutral,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EmptyStateTone tone;

  Color get _accent => switch (tone) {
        EmptyStateTone.neutral => ShadowColors.primary,
        EmptyStateTone.error => ShadowColors.error,
      };

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
                color: _accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: _accent),
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
