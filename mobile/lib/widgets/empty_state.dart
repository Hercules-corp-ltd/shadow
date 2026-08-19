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
///
/// The disc used to be a flat wash of the accent at 12% — a coloured coin
/// floating in the middle of an otherwise empty screen, and on a screen with
/// nothing else on it that coin *is* the design. It is now a socket cut into
/// the page with the light of the icon inside it: a ring at the edge, a faint
/// bloom under the glyph, and the accent carried by the glyph rather than by
/// a filled shape. Same two tones, so failure still does not look like
/// emptiness.
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
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: ShadowColors.recessDeep,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accent.withValues(alpha: 0.22),
                ),
                boxShadow: <BoxShadow>[
                  // Inside the socket, not under it: a low bloom the glyph
                  // appears to be casting onto the wall of the recess.
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.14),
                    blurRadius: 26,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 30,
                color: _accent.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: ShadowTypography.h3, textAlign: TextAlign.center),
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
